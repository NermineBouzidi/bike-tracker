#ifndef TRACK_H
#define TRACK_H

#include <stdint.h>
#include <stdbool.h>
#include "nmea_parser.h"

typedef struct {
    int32_t lat_e6, lon_e6;
    bool    have;        /* a previous point exists */
    float   total_m;     /* distance travelled */
} Track_t;

void track_update(Track_t *t, const GpsData_t *g);
void track_lost(Track_t *t);   /* call when the fix is lost for a while */

#endif
