#include "app_rtos.h"
#include "main.h"
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "queue.h"
#include "ble_service.h"
#include "nmea_parser.h"
#include "track.h"
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdbool.h>

#if APP_LOG_SD
#include "sd_test.h"
#endif

extern UART_HandleTypeDef huart1;
extern UART_HandleTypeDef huart4;
extern uint8_t gps_byte;

/* ---------------- FreeRTOS objects ---------------- */
static SemaphoreHandle_t s_sem0, s_sem1, s_sem2, s_sem3;   /* tokens of the diagram */
static SemaphoreHandle_t s_pinSem;                         /* Pin_Interrupt -> Bike_State */
static SemaphoreHandle_t s_logMtx;
static QueueHandle_t     s_gpsLineQ;                       /* raw RMC lines (ISR -> GPS_Get_Data) */
static QueueHandle_t     s_bleQ, s_gpsQ, s_histQ;          /* BLE_Queue, GPS_Queue, History_Queue */

/* ---------------- Shared state ---------------- */
static NmeaLine_t        s_nmea;                           /* used only by the UART4 interrupt */
static Track_t           s_trk;
static volatile uint8_t  s_historyFlag;
static volatile uint8_t  s_cycleHistory;

/* Circular memory in RAM (used only by Mem_Access_Data) */
static GpsRecord_t s_ring[APP_HIST_RAM_RECORDS];
static uint16_t    s_head, s_count;

/* ---------------- Log ---------------- */
void App_Log(const char *fmt, ...)
{
    char b[128];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(b, sizeof(b), fmt, ap);
    va_end(ap);
    if (n <= 0) return;
    if (n > (int)sizeof(b) - 1) n = (int)sizeof(b) - 1;

    /* before the scheduler starts there is only one thread: no mutex needed */
    const int useMtx = (s_logMtx != NULL) && (xTaskGetSchedulerState() == taskSCHEDULER_RUNNING);
    if (useMtx) xSemaphoreTake(s_logMtx, portMAX_DELAY);
    HAL_UART_Transmit(&huart1, (uint8_t *)b, (uint16_t)n, 100);
    if (useMtx) xSemaphoreGive(s_logMtx);
}

/* ---------------- Inputs from interrupts ---------------- */
void App_GpsRxByteFromISR(char c)
{
    if (!s_gpsLineQ) return;
    if (nmea_line_feed(&s_nmea, c)) {
        if (strncmp(&s_nmea.buf[3], "RMC", 3) != 0) return;   /* only RMC lines are useful */
        char tmp[NMEA_MAX_LEN];
        memcpy(tmp, s_nmea.buf, NMEA_MAX_LEN);
        tmp[NMEA_MAX_LEN - 1] = '\0';
        BaseType_t woken = pdFALSE;
        (void)xQueueSendFromISR(s_gpsLineQ, tmp, &woken);     /* queue full: the line is lost, which is harmless */
        portYIELD_FROM_ISR(woken);
    }
}

void App_MotionFromISR(void)
{
    if (!s_pinSem) return;
    BaseType_t woken = pdFALSE;
    (void)xSemaphoreGiveFromISR(s_pinSem, &woken);
    portYIELD_FROM_ISR(woken);
}

void App_RequestHistory(void)
{
    s_historyFlag = 1;
}

/* ---------------- Task 1: Bike_State ---------------- */
static void Task_BikeState(void *arg)
{
    (void)arg;
    TickType_t lastMotion = 0;
    uint8_t awake = 0;

    for (;;) {
        xSemaphoreTake(s_sem0, portMAX_DELAY);                       /* Acquire Sem0 */
        TickType_t now = xTaskGetTickCount();

        uint8_t pin = 0;                                             /* [Pin_Interrupt = 1] ? */
#if APP_TEST_FORCE_MOTION
        (void)xSemaphoreTake(s_pinSem, 0);
        pin = 1;
#else
        if (xSemaphoreTake(s_pinSem, awake ? 0 : pdMS_TO_TICKS(1000)) == pdTRUE) pin = 1;
        now = xTaskGetTickCount();
#endif
        if (pin) {
            lastMotion = now;
            if (!awake) {                                            /* leave sleep mode */
                awake = 1;
                App_Log("[BIKE] motion -> active\r\n");
            }
        }
        if (awake && (now - lastMotion) >= pdMS_TO_TICKS(APP_SLEEP_TIMEOUT_MS)) {
            awake = 0;                                               /* timer elapsed: enter sleep mode */
            App_Log("[BIKE] %lu s without motion -> sleep\r\n", (unsigned long)(APP_SLEEP_TIMEOUT_MS / 1000u));
        }

        if (awake) xSemaphoreGive(s_sem1);                           /* Release Sem1: one GPS cycle */
        else       xSemaphoreGive(s_sem0);                           /* asleep: give the token back and loop */
    }
}

/* ---------------- Task 2: GPS_Get_Data ---------------- */
static bool gps_wait_fix(GpsData_t *g, uint32_t timeout_ms)
{
    char line[NMEA_MAX_LEN];
    const TickType_t t0 = xTaskGetTickCount();
    const TickType_t to = pdMS_TO_TICKS(timeout_ms);

    xQueueReset(s_gpsLineQ);                                         /* ignore stale lines */
    for (;;) {
        TickType_t el = xTaskGetTickCount() - t0;
        if (el >= to) return false;
        if (xQueueReceive(s_gpsLineQ, line, to - el) != pdTRUE) return false;
        if (nmea_parse_rmc(line, g)) return true;
    }
}

#if APP_TEST_SIMULATE_GPS
static void gps_fake(GpsData_t *g)
{
    static int32_t lat = 36800000;
    uint32_t s = (uint32_t)(xTaskGetTickCount() / 1000u);
    lat += 90;                                                       /* about 10 m north per cycle */
    memset(g, 0, sizeof(*g));
    g->valid = true;
    g->year = 2026; g->month = 11; g->day = 11;
    g->hour = (uint8_t)((s / 3600u) % 24u);
    g->minute = (uint8_t)((s / 60u) % 60u);
    g->second = (uint8_t)(s % 60u);
    g->lat_e6 = lat;
    g->lon_e6 = 10180000;
    g->speed_dkmh = 360;
}
#endif

static void Task_GpsGetData(void *arg)
{
    (void)arg;
    TickType_t lastFix = 0;
    uint32_t cycles = 0;

    /* start the GPS reception here: the queue exists and the scheduler is running */
    (void)HAL_UART_Receive_IT(&huart4, &gps_byte, 1);

    for (;;) {
        xSemaphoreTake(s_sem1, portMAX_DELAY);                       /* Acquire Sem1 */
        cycles++;
#if APP_TEST_HISTORY_EVERY > 0
        if ((cycles % APP_TEST_HISTORY_EVERY) == 0u) s_historyFlag = 1;
#else
        (void)cycles;
#endif
        if (s_historyFlag) {                                         /* check the history request */
            s_historyFlag = 0;
            s_cycleHistory = 1;
            App_Log("[GPS] history request\r\n");
            xSemaphoreGive(s_sem2);                                  /* [History_Flag=1] Release Sem2 */
            continue;
        }

        s_cycleHistory = 0;                                          /* [History_Flag=0] provide the data */
        GpsData_t gps;
        if (!gps_wait_fix(&gps, 3000)) {
#if APP_TEST_SIMULATE_GPS
            gps_fake(&gps);                                          /* indoor test: FAKE position */
#else
            App_Log("NO FIX\r\n");
            xSemaphoreGive(s_sem0);                                  /* cycle dropped: give the token back */
            continue;
#endif
        }

        TickType_t now = xTaskGetTickCount();
        if (s_trk.have && (now - lastFix) > pdMS_TO_TICKS(5000)) track_lost(&s_trk);  /* no phantom distance */
        lastFix = now;

        GpsRecord_t rec;
        record_make(&gps, &rec);
        track_update(&s_trk, &gps);

        (void)xQueueSend(s_bleQ, &rec, 0);                           /* store in BLE_Queue */
        (void)xQueueSend(s_gpsQ, &rec, 0);                           /* store in GPS_Queue */
        App_Log("FIX ts=%lu lat=%ld lon=%ld v=%u d=%lum\r\n",
                (unsigned long)rec.ts, (long)rec.lat_e6, (long)rec.lon_e6,
                rec.speed_dkmh, (unsigned long)s_trk.total_m);
        xSemaphoreGive(s_sem2);                                      /* Release Sem2 */
    }
}

/* ---------------- Task 3: Mem_Access_Data ---------------- */
static void ring_push(const GpsRecord_t *r)
{
    s_ring[s_head] = *r;
    s_head = (uint16_t)((s_head + 1u) % APP_HIST_RAM_RECORDS);
    if (s_count < APP_HIST_RAM_RECORDS) s_count++;
}

static void Task_MemAccess(void *arg)
{
    (void)arg;
    for (;;) {
        xSemaphoreTake(s_sem2, portMAX_DELAY);                       /* Acquire Sem2 */

        if (s_cycleHistory) {
            /* read the history from memory -> History_Queue (oldest first) */
            uint16_t n = (s_count < APP_HIST_PAGE) ? s_count : (uint16_t)APP_HIST_PAGE;
            uint16_t start = (uint16_t)((s_head + APP_HIST_RAM_RECORDS - n) % APP_HIST_RAM_RECORDS);
            xQueueReset(s_histQ);
            for (uint16_t i = 0; i < n; i++) {
                (void)xQueueSend(s_histQ, &s_ring[(start + i) % APP_HIST_RAM_RECORDS], 0);
            }
        } else {
            /* GPS_Queue -> store in memory */
            GpsRecord_t r;
            while (xQueueReceive(s_gpsQ, &r, 0) == pdTRUE) {
                ring_push(&r);
#if APP_LOG_SD
                char line[64];
                snprintf(line, sizeof(line), "%lu,%ld,%ld,%u\r\n",
                         (unsigned long)r.ts, (long)r.lat_e6, (long)r.lon_e6, r.speed_dkmh);
                (void)SD_LogLine("TRIPS.CSV", line);
#endif
            }
        }
        xSemaphoreGive(s_sem3);                                      /* Release Sem3 */
    }
}

/* ---------------- Task 4: BLE_Send_Data ---------------- */
static void Task_BleSend(void *arg)
{
    (void)arg;
    GpsRecord_t r;

    for (;;) {
        /* the BlueNRG must be served all the time (connect, disconnect...): wait for Sem3 only 10 ms */
        if (xSemaphoreTake(s_sem3, pdMS_TO_TICKS(10)) != pdTRUE) {   /* Acquire Sem3 */
            BLE_ProcessEvents();
            continue;
        }
        BLE_ProcessEvents();

        if (s_cycleHistory) {
            /* History_Queue -> send to the application */
            uint32_t sent = 0;
            while (xQueueReceive(s_histQ, &r, 0) == pdTRUE) {
                if (BLE_IsConnected()) {
                    BLE_SendRecord(&r);
                    sent++;
                    vTaskDelay(pdMS_TO_TICKS(30));                   /* let the notification go out */
                    BLE_ProcessEvents();
                }
            }
            App_Log("[BLE] history sent: %lu records\r\n", (unsigned long)sent);
        } else {
            /* BLE_Queue -> send to the application */
            while (xQueueReceive(s_bleQ, &r, 0) == pdTRUE) {
                BLE_SendRecord(&r);
                BLE_SendDistance((uint32_t)s_trk.total_m);
            }
        }
        xSemaphoreGive(s_sem0);                                      /* Release Sem0: end of the cycle */
    }
}

/* ---------------- Creation ---------------- */
void App_RTOS_Init(void)
{
    s_logMtx   = xSemaphoreCreateMutex();
    s_sem0     = xSemaphoreCreateBinary();
    s_sem1     = xSemaphoreCreateBinary();
    s_sem2     = xSemaphoreCreateBinary();
    s_sem3     = xSemaphoreCreateBinary();
    s_pinSem   = xSemaphoreCreateBinary();
    s_gpsLineQ = xQueueCreate(4, NMEA_MAX_LEN);
    s_bleQ     = xQueueCreate(8, sizeof(GpsRecord_t));
    s_gpsQ     = xQueueCreate(8, sizeof(GpsRecord_t));
    s_histQ    = xQueueCreate(APP_HIST_PAGE, sizeof(GpsRecord_t));

    if (!s_logMtx || !s_sem0 || !s_sem1 || !s_sem2 || !s_sem3 || !s_pinSem ||
        !s_gpsLineQ || !s_bleQ || !s_gpsQ || !s_histQ) {
        Error_Handler();                                             /* out of heap: raise TOTAL_HEAP_SIZE */
    }

    xSemaphoreGive(s_sem0);                                          /* the first cycle can start */

    if (xTaskCreate(Task_BikeState,  "Bike_State",   768, NULL, tskIDLE_PRIORITY + 2, NULL) != pdPASS ||
        xTaskCreate(Task_GpsGetData, "GPS_Get_Data", 768, NULL, tskIDLE_PRIORITY + 3, NULL) != pdPASS ||
        xTaskCreate(Task_MemAccess,  "Mem_Access",   768, NULL, tskIDLE_PRIORITY + 2, NULL) != pdPASS ||
        xTaskCreate(Task_BleSend,    "BLE_Send",    1024, NULL, tskIDLE_PRIORITY + 3, NULL) != pdPASS) {
        Error_Handler();
    }
}

/* ---------------- Safety hooks (need the two defines of step 4) ---------------- */
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    (void)xTask;
    __disable_irq();
    const char m[] = "\r\nSTACK OVERFLOW in task: ";
    HAL_UART_Transmit(&huart1, (uint8_t *)m, sizeof(m) - 1, 100);
    HAL_UART_Transmit(&huart1, (uint8_t *)pcTaskName, (uint16_t)strlen(pcTaskName), 100);
    for (;;) { }
}

void vApplicationMallocFailedHook(void)
{
    __disable_irq();
    const char m[] = "\r\nOUT OF HEAP\r\n";
    HAL_UART_Transmit(&huart1, (uint8_t *)m, sizeof(m) - 1, 100);
    for (;;) { }
}
