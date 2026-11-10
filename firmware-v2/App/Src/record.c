#include "record.h"
#include <string.h>

static uint16_t crc16(const uint8_t *d, uint32_t n)
{
    uint16_t crc = 0xFFFF;
    while (n--) {
        crc ^= (uint16_t)(*d++) << 8;
        for (int i = 0; i < 8; i++)
            crc = (crc & 0x8000) ? (uint16_t)((crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
    }
    return crc;
}

static int32_t days_from_civil(int y, unsigned m, unsigned d)
{
    y -= (m <= 2);
    int era = (y >= 0 ? y : y - 399) / 400;
    unsigned yoe = (unsigned)(y - era * 400);
    unsigned doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
    unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + (int32_t)doe - 719468;
}

uint32_t record_unix_time(const GpsData_t *g)
{
    int32_t days = days_from_civil(g->year, g->month, g->day);
    return (uint32_t)days * 86400u + g->hour * 3600u + g->minute * 60u + g->second;
}

void record_make(const GpsData_t *g, GpsRecord_t *r)
{
    r->ts = record_unix_time(g);
    r->lat_e6 = g->lat_e6;
    r->lon_e6 = g->lon_e6;
    r->speed_dkmh = g->speed_dkmh;
    r->crc = crc16((const uint8_t *)r, 14);
}

bool record_valid(const GpsRecord_t *r)
{
    return r->crc == crc16((const uint8_t *)r, 14);
}

bool record_is_erased(const GpsRecord_t *r)
{
    const uint8_t *p = (const uint8_t *)r;
    for (int i = 0; i < 16; i++) if (p[i] != 0xFF) return false;
    return true;
}
