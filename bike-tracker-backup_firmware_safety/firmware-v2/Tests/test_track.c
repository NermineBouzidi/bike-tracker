#include <stdio.h>
#include <math.h>
#include "record.h"
#include "track.h"

static int fails = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } } while (0)

int main(void)
{
    GpsData_t g = {0};
    g.year = 2000; g.month = 1; g.day = 1;
    CHECK(record_unix_time(&g) == 946684800u);
    g.year = 2026;
    CHECK(record_unix_time(&g) == 1767225600u);

    GpsRecord_t r;
    g.lat_e6 = 36800000; g.lon_e6 = 10180000; g.speed_dkmh = 123;
    record_make(&g, &r);
    CHECK(record_valid(&r));
    r.lat_e6 += 1;
    CHECK(!record_valid(&r));            /* a corrupted record is rejected */

    Track_t t = {0};
    g.speed_dkmh = 100;
    track_update(&t, &g);
    g.lat_e6 = 36801000;                  /* +0.001 degree = about 111 m */
    track_update(&t, &g);
    CHECK(fabsf(t.total_m - 111.2f) < 2.5f);

    g.lat_e6 = 36802000; g.speed_dkmh = 0; /* standing still: not counted */
    float before = t.total_m;
    track_update(&t, &g);
    CHECK(t.total_m == before);

    if (!fails) printf("All tests passed\n");
    return fails;
}
