#include <stdio.h>
#include <string.h>
#include "nmea_parser.h"

static int fails = 0;

#define CHECK(cond) do { \
    if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); fails++; } \
} while (0)

int main(void)
{
    GpsData_t d;

    /* Frames from your real GPS (no fix) */
    CHECK(nmea_verify_checksum("$GPRMC,,V,,,,,,,,,,N*53"));
    CHECK(nmea_verify_checksum("$GPVTG,,,,,,,,,N*30"));
    CHECK(!nmea_parse_rmc("$GPRMC,,V,,,,,,,,,,N*53", &d));
    CHECK(!d.valid);

    /* A valid fix (classic NMEA example) */
    const char *ok = "$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A";
    CHECK(nmea_verify_checksum(ok));
    CHECK(nmea_parse_rmc(ok, &d));
    CHECK(d.valid);
    CHECK(d.hour == 12 && d.minute == 35 && d.second == 19);
    CHECK(d.day == 23 && d.month == 3 && d.year == 2094);
    CHECK(d.lat_e6 == 48117300);
    CHECK(d.lon_e6 == 11516666);
    CHECK(d.speed_dkmh == 414);

    /* Corrupted checksum must be rejected */
    CHECK(!nmea_verify_checksum("$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6B"));

    /* Line assembler: junk before '$' is ignored */
    NmeaLine_t l = {0};
    const char *in = "junk$GPRMC,,V,,,,,,,,,,N*53\r\n";
    int done = 0;
    for (const char *p = in; *p; p++) done = nmea_line_feed(&l, *p);
    CHECK(done);
    CHECK(strcmp(l.buf, "$GPRMC,,V,,,,,,,,,,N*53") == 0);

    if (fails == 0) printf("All tests passed\n");
    return fails;
}