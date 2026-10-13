#ifndef NMEA_PARSER_H
#define NMEA_PARSER_H

#include <stdint.h>
#include <stdbool.h>

#define NMEA_MAX_LEN 96

typedef struct {
    bool     valid;                  /* true only if the GPS has a fix */
    uint8_t  hour, minute, second;   /* UTC time */
    uint8_t  day, month;
    uint16_t year;
    int32_t  lat_e6;                 /* latitude  in degrees x 1,000,000 */
    int32_t  lon_e6;                 /* longitude in degrees x 1,000,000 */
    uint16_t speed_dkmh;             /* speed in units of 0.1 km/h */
} GpsData_t;

/* Collects characters one by one into a complete line */
typedef struct {
    char    buf[NMEA_MAX_LEN];
    uint8_t len;
    bool    active;
} NmeaLine_t;

bool nmea_line_feed(NmeaLine_t *l, char c);       /* true when a full line is ready */
bool nmea_verify_checksum(const char *line);      /* true if the checksum is correct */
bool nmea_parse_rmc(const char *line, GpsData_t *out);  /* true only for a valid fix */

#endif
