#ifndef NMEA_PARSER_H
#define NMEA_PARSER_H

#include <stdint.h>
#include <stdbool.h>

#define NMEA_MAX_LEN 96

typedef struct {
    bool     valid;
    uint8_t  hour, minute, second;
    uint8_t  day, month;
    uint16_t year;
    int32_t  lat_e6;
    int32_t  lon_e6;
    uint16_t speed_dkmh;
} GpsData_t;

typedef struct {
    char    buf[NMEA_MAX_LEN];
    uint8_t len;
    bool    active;
} NmeaLine_t;

bool nmea_line_feed(NmeaLine_t *l, char c);
bool nmea_verify_checksum(const char *line);
bool nmea_parse_rmc(const char *line, GpsData_t *out);

#endif
