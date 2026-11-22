#ifndef APP_RTOS_H
#define APP_RTOS_H

/* BikeTrack - 4 FreeRTOS tasks linked by semaphores and queues
 * (activity diagram: Bike_State / GPS_Get_Data / Mem_Access_Data / BLE_Send_Data).
 *
 *   Sem0 : cycle token       (BLE_Send_Data   -> Bike_State)
 *   Sem1 : "one GPS cycle"   (Bike_State      -> GPS_Get_Data)
 *   Sem2 : "memory to do"    (GPS_Get_Data    -> Mem_Access_Data)
 *   Sem3 : "BLE to do"       (Mem_Access_Data -> BLE_Send_Data)
 *   BLE_Queue / GPS_Queue / History_Queue : GpsRecord_t records
 */

#include <stdint.h>
#include "record.h"

/* ---------------- Options ---------------- */
#ifndef APP_TEST_FORCE_MOTION
#define APP_TEST_FORCE_MOTION   1      /* 1 = ignore the motion sensor: the bike is always "moving" */
#endif
#ifndef APP_SLEEP_TIMEOUT_MS
#define APP_SLEEP_TIMEOUT_MS    30000  /* no motion for this long -> sleep mode (30 s timer) */
#endif
#ifndef APP_TEST_SIMULATE_GPS
#define APP_TEST_SIMULATE_GPS   0      /* 1 = FAKE moving position when there is no fix (indoor tests only) */
#endif
#ifndef APP_TEST_HISTORY_EVERY
#define APP_TEST_HISTORY_EVERY  0      /* N > 0: automatic history request every N cycles (test) */
#endif
#ifndef APP_HIST_RAM_RECORDS
#define APP_HIST_RAM_RECORDS    256u   /* circular memory in RAM (until the SD card is added) */
#endif
#ifndef APP_HIST_PAGE
#define APP_HIST_PAGE           16u    /* records sent per history request */
#endif
#ifndef APP_LOG_SD
#define APP_LOG_SD              0      /* keep 0 until the SD card driver exists */
#endif

/* ---------------- API ---------------- */
void App_RTOS_Init(void);                 /* creates semaphores, queues and tasks (before the scheduler starts) */
void App_GpsRxByteFromISR(char c);        /* from HAL_UART_RxCpltCallback (UART4) */
void App_MotionFromISR(void);             /* from HAL_GPIO_EXTI_Callback (motion input) */
void App_RequestHistory(void);            /* history request (later: BLE write on a control characteristic) */
void App_Log(const char *fmt, ...);       /* printf to USART1 (tasks and start-up code only, never from an interrupt) */

#endif /* APP_RTOS_H */
