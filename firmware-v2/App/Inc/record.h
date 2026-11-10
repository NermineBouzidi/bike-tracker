#ifndef RECORD_H
#define RECORD_H

#include <stdint.h>
#include <stdbool.h>
#include "nmea_parser.h"

typedef struct __attribute__((packed)) {
    uint32_t ts;          /* seconds since 1970, UTC */
    int32_t  lat_e6;
    int32_t  lon_e6;
    uint16_t speed_dkmh;  /* 0.1 km/h */
    uint16_t crc;         /* CRC-16 of the first 14 bytes */
} GpsRecord_t;

_Static_assert(sizeof(GpsRecord_t) == 16, "record must be 16 bytes");

uint32_t record_unix_time(const GpsData_t *g);
void     record_make(const GpsData_t *g, GpsRecord_t *r);
bool     record_valid(const GpsRecord_t *r);   /* CRC ok */
bool     record_is_erased(const GpsRecord_t *r); /* all bytes 0xFF */

#endif
