#ifndef RTC_TIME_H
#define RTC_TIME_H

#include <stdint.h>
#include "nmea_parser.h"   /* GpsData_t */

#define RTC_BKP_MAGIC 0x32F2u   /* in RTC_BKP_DR0 once the RTC holds a real date */

void     RTC_SetFromGps(const GpsData_t *g);
uint8_t  RTC_IsSet(void);
uint32_t RTC_GetUnix(void);     /* 0 if never set */

#endif
