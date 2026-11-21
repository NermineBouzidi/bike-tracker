#include "timeutil.h"

/* H. Hinnant's algorithms, valid for any date after 1970 */
uint32_t time_days_from_ymd(int y, unsigned m, unsigned d)
{
    y -= (m <= 2);
    int era = y / 400;
    unsigned yoe = (unsigned)(y - era * 400);
    unsigned doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
    unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return (uint32_t)(era * 146097 + (int)doe - 719468);
}

void time_ymd_from_days(uint32_t days, unsigned *y, unsigned *m, unsigned *d)
{
    int32_t  z   = (int32_t)days + 719468;
    int32_t  era = z / 146097;
    uint32_t doe = (uint32_t)(z - era * 146097);
    uint32_t yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    uint32_t doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    uint32_t mp  = (5 * doy + 2) / 153;
    *d = doy - (153 * mp + 2) / 5 + 1;
    *m = (mp < 10) ? mp + 3 : mp - 9;
    *y = (unsigned)((int32_t)yoe + era * 400) + (*m <= 2);
}

uint8_t time_weekday(uint32_t days)
{
    return (uint8_t)(((days + 3u) % 7u) + 1u);   /* 1970-01-01 was a Thursday (= 4) */
}
