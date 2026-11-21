#ifndef TIMEUTIL_H
#define TIMEUTIL_H

/* Pure date helpers (no HAL): used by sd_log, rtc_time and the PC tests. */
#include <stdint.h>

uint32_t time_days_from_ymd(int y, unsigned m, unsigned d);          /* days since 1970-01-01 */
void     time_ymd_from_days(uint32_t days, unsigned *y, unsigned *m, unsigned *d);
uint8_t  time_weekday(uint32_t days);                                /* 1 = Monday ... 7 = Sunday */

#endif
