#include "track.h"
#include <math.h>

#define EARTH_R_M      6371000.0f
#define DEG_E6_TO_RAD  (3.14159265f / 180.0f / 1000000.0f)
#define MIN_SPEED_DKMH 10      /* below 1 km/h: treat as standing still */
#define MAX_JUMP_M     150.0f  /* more than this in one update: a glitch, not riding */

static float haversine_m(int32_t lat1, int32_t lon1, int32_t lat2, int32_t lon2)
{
    float p1 = lat1 * DEG_E6_TO_RAD, p2 = lat2 * DEG_E6_TO_RAD;
    float dp = (lat2 - lat1) * DEG_E6_TO_RAD;
    float dl = (lon2 - lon1) * DEG_E6_TO_RAD;
    float s1 = sinf(dp / 2.0f), s2 = sinf(dl / 2.0f);
    float a = s1 * s1 + cosf(p1) * cosf(p2) * s2 * s2;
    if (a > 1.0f) a = 1.0f;
    return 2.0f * EARTH_R_M * asinf(sqrtf(a));
}

void track_update(Track_t *t, const GpsData_t *g)
{
    if (t->have && g->speed_dkmh >= MIN_SPEED_DKMH) {
        float d = haversine_m(t->lat_e6, t->lon_e6, g->lat_e6, g->lon_e6);
        if (d < MAX_JUMP_M) t->total_m += d;
    }
    t->lat_e6 = g->lat_e6;
    t->lon_e6 = g->lon_e6;
    t->have = true;
}

void track_lost(Track_t *t)
{
    t->have = false;   /* the next point restarts the path, no phantom jump */
}
