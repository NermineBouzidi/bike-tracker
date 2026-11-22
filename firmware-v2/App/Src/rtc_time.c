#include "rtc_time.h"
#include "main.h"

extern RTC_HandleTypeDef hrtc;

/* y/m/d -> days since 1970-01-01 (H. Hinnant algorithm) */
static uint32_t days_from_civil(int y, unsigned m, unsigned d)
{
    y -= (m <= 2);
    int era = y / 400;
    unsigned yoe = (unsigned)(y - era * 400);
    unsigned doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return (uint32_t)(era * 146097 + (int)doe - 719468);
}

uint8_t RTC_IsSet(void)
{
    return HAL_RTCEx_BKUPRead(&hrtc, RTC_BKP_DR0) == RTC_BKP_MAGIC;
}

void RTC_SetFromGps(const GpsData_t *g)
{
    if (!g->valid || g->year < 2020) return;

    RTC_TimeTypeDef t = {0};
    RTC_DateTypeDef d = {0};
    t.Hours = g->hour;
    t.Minutes = g->minute;
    t.Seconds = g->second;
    t.DayLightSaving = RTC_DAYLIGHTSAVING_NONE;
    t.StoreOperation = RTC_STOREOPERATION_RESET;
    d.Year = (uint8_t)(g->year - 2000);
    d.Month = g->month;
    d.Date = g->day;
    d.WeekDay = (uint8_t)(((days_from_civil(g->year, g->month, g->day) + 3u) % 7u) + 1u); /* 1 = Monday */

    if (HAL_RTC_SetTime(&hrtc, &t, RTC_FORMAT_BIN) == HAL_OK &&
        HAL_RTC_SetDate(&hrtc, &d, RTC_FORMAT_BIN) == HAL_OK) {
        HAL_RTCEx_BKUPWrite(&hrtc, RTC_BKP_DR0, RTC_BKP_MAGIC);
    }
}

uint32_t RTC_GetUnix(void)
{
    if (!RTC_IsSet()) return 0;
    RTC_TimeTypeDef t;
    RTC_DateTypeDef d;
    HAL_RTC_GetTime(&hrtc, &t, RTC_FORMAT_BIN);   /* GetTime THEN GetDate (unlocks the shadow registers) */
    HAL_RTC_GetDate(&hrtc, &d, RTC_FORMAT_BIN);
    return days_from_civil(2000 + d.Year, d.Month, d.Date) * 86400u
         + t.Hours * 3600u + t.Minutes * 60u + t.Seconds;
}
