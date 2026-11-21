#include "power.h"
#include "main.h"
#include "app_log.h"
#include <string.h>

extern UART_HandleTypeDef huart4;
extern void SystemClock_Config(void);

static volatile uint32_t s_lastMotion;
static volatile bool     s_motionEvent;

/* ================= Motion ================= */
#if MOTION_USE_LSM6DSL
extern I2C_HandleTypeDef hi2c2;
#define LSM_ADDR        0xD4u      /* SA0 = 1 on the B-L475E-IOT01A */
#define LSM_WHO_AM_I    0x0Fu      /* must read 0x6A */
#define LSM_CTRL1_XL    0x10u
#define LSM_CTRL6_C     0x15u
#define LSM_TAP_CFG     0x58u
#define LSM_WAKE_THS    0x5Bu
#define LSM_WAKE_DUR    0x5Cu
#define LSM_MD1_CFG     0x5Eu

static HAL_StatusTypeDef lsm_wr(uint8_t reg, uint8_t val)
{
    return HAL_I2C_Mem_Write(&hi2c2, LSM_ADDR, reg, I2C_MEMADD_SIZE_8BIT, &val, 1, 50);
}
#endif

void Motion_Init(void)
{
    s_lastMotion = HAL_GetTick();
#if MOTION_USE_LSM6DSL
    uint8_t id = 0;
    HAL_I2C_Mem_Read(&hi2c2, LSM_ADDR, LSM_WHO_AM_I, I2C_MEMADD_SIZE_8BIT, &id, 1, 50);
    App_Log("[MOTION] LSM6DSL id=0x%02X (expect 0x6A)\r\n", id);
    lsm_wr(LSM_CTRL1_XL, 0x20);   /* 26 Hz, +-2 g */
    lsm_wr(LSM_CTRL6_C,  0x10);   /* low-power mode (XL_HM_MODE = 1): about 10 uA */
    lsm_wr(LSM_WAKE_DUR, 0x00);
    lsm_wr(LSM_WAKE_THS, 0x02);   /* 2 x 31 mg: tune it on the bike */
    lsm_wr(LSM_TAP_CFG,  0x80);   /* enable the wake-up interrupt logic */
    lsm_wr(LSM_MD1_CFG,  0x20);   /* wake-up event -> INT1 (PD11) */
#else
    App_Log("[MOTION] dynamo input (EXTI)\r\n");
#endif
}

void Motion_FromISR(void)
{
    s_lastMotion = HAL_GetTick();
    s_motionEvent = true;
}

bool Motion_TakeEvent(void)
{
    if (!s_motionEvent) return false;
    s_motionEvent = false;
    return true;
}

uint32_t Motion_IdleMs(void) { return HAL_GetTick() - s_lastMotion; }

/* ================= GPS power ================= */
#ifndef GPS_EN_Pin
static void ubx_send(uint8_t cls, uint8_t id, const uint8_t *pl, uint16_t len)
{
    uint8_t h[6] = {0xB5, 0x62, cls, id, (uint8_t)len, (uint8_t)(len >> 8)};
    uint8_t a = 0, b = 0;
    for (int i = 2; i < 6; i++) { a += h[i]; b += a; }
    for (uint16_t i = 0; i < len; i++) { a += pl[i]; b += a; }
    uint8_t ck[2] = {a, b};
    HAL_UART_Transmit(&huart4, h, 6, 50);
    HAL_UART_Transmit(&huart4, (uint8_t *)pl, len, 50);
    HAL_UART_Transmit(&huart4, ck, 2, 50);
}
#endif

void GPS_PowerOff(void)
{
#ifdef GPS_EN_Pin
    HAL_GPIO_WritePin(GPS_EN_GPIO_Port, GPS_EN_Pin, GPIO_PIN_RESET);   /* check your MOSFET polarity */
#else
    /* UBX-RXM-PMREQ: backup mode, infinite duration. The module keeps ephemeris
       (fast fix after wake-up) if its backup battery is fitted. */
    static const uint8_t pl[8] = {0, 0, 0, 0, 0x02, 0, 0, 0};
    ubx_send(0x02, 0x41, pl, sizeof(pl));
#endif
}

void GPS_PowerOn(void)
{
#ifdef GPS_EN_Pin
    HAL_GPIO_WritePin(GPS_EN_GPIO_Port, GPS_EN_Pin, GPIO_PIN_SET);
#else
    /* activity on the GPS RX line wakes a u-blox module from backup mode */
    static const uint8_t wake[8] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
    HAL_UART_Transmit(&huart4, (uint8_t *)wake, sizeof(wake), 50);
#endif
}

/* ================= Stop2 ================= */
void Power_EnterStop2(void)
{
    uint32_t systick = SysTick->CTRL;
    SysTick->CTRL &= ~SysTick_CTRL_TICKINT_Msk;          /* FreeRTOS tick off during sleep */
    HAL_SuspendTick();                                   /* HAL tick (TIM6) off */
    __HAL_PWR_CLEAR_FLAG(PWR_FLAG_WUF1 | PWR_FLAG_WUF2 | PWR_FLAG_WUF3 | PWR_FLAG_WUF4 | PWR_FLAG_WUF5);
    __HAL_RCC_WAKEUPSTOP_CLK_CONFIG(RCC_STOP_WAKEUPCLOCK_MSI);
    HAL_PWREx_EnterSTOP2Mode(PWR_STOPENTRY_WFI);         /* ... sleeping ... */

    SystemClock_Config();                                /* back to 80 MHz */
    HAL_ResumeTick();
    SysTick->CTRL = systick;                             /* FreeRTOS tick back on */
}
