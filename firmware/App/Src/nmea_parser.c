#include "nmea_parser.h"
#include <string.h>

static bool is_digit(char c) { return c >= '0' && c <= '9'; }

static int hex_val(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

bool nmea_line_feed(NmeaLine_t *l, char c)
{
    if (c == '$') { l->len = 0; l->active = true; }
    if (!l->active || c == '\r') return false;

    if (c == '\n') {
        l->active = false;
        l->buf[l->len] = '\0';
        return l->len >= 6;
    }
    if (l->len >= NMEA_MAX_LEN - 1) {
        l->active = false;
        l->len = 0;
        return false;
    }
    l->buf[l->len++] = c;
    return false;
}

bool nmea_verify_checksum(const char *s)
{
    if (s == NULL || s[0] != '$') return false;

    uint8_t cs = 0;
    const char *p = s + 1;
    while (*p != '\0' && *p != '*') cs ^= (uint8_t)*p++;
    if (*p != '*') return false;

    int hi = hex_val(p[1]);
    int lo = hex_val(p[2]);
    if (hi < 0 || lo < 0) return false;
    return cs == (uint8_t)((hi << 4) | lo);
}

/* Splits a line on ',' and keeps empty fields (needed when there is no fix) */
static int split_fields(char *s, char *fields[], int max)
{
    int n = 0;
    fields[n++] = s;
    while (*s != '\0') {
        if (*s == ',' && n < max) {
            *s = '\0';
            fields[n++] = s + 1;
        }
        s++;
    }
    return n;
}

static bool parse_2digits(const char *s, uint8_t *out)
{
    if (!is_digit(s[0]) || !is_digit(s[1])) return false;
    *out = (uint8_t)((s[0] - '0') * 10 + (s[1] - '0'));
    return true;
}

/* "ddmm.mmmm" or "dddmm.mmmm" -> degrees x 1e6 */
static bool parse_coord(const char *f, char hemi, int deg_digits, int32_t *out)
{
    if (strlen(f) < (size_t)deg_digits + 3) return false;

    int32_t deg = 0;
    for (int i = 0; i < deg_digits; i++) {
        if (!is_digit(f[i])) return false;
        deg = deg * 10 + (f[i] - '0');
    }

    const char *m = f + deg_digits;
    if (!is_digit(m[0]) || !is_digit(m[1]) || m[2] != '.') return false;
    uint32_t min_int = (uint32_t)((m[0] - '0') * 10 + (m[1] - '0'));

    uint32_t frac = 0;
    int digits = 0;
    for (const char *p = m + 3; *p != '\0' && digits < 5; p++, digits++) {
        if (!is_digit(*p)) return false;
        frac = frac * 10 + (uint32_t)(*p - '0');
    }
    for (; digits < 5; digits++) frac *= 10;

    uint32_t min_e5 = min_int * 100000u + frac;
    int32_t v = deg * 1000000 + (int32_t)((min_e5 * 10u) / 60u);

    if (hemi == 'S' || hemi == 'W')      v = -v;
    else if (hemi != 'N' && hemi != 'E') return false;

    *out = v;
    return true;
}

/* "12.34" -> 1234 (two decimals) */
static bool parse_fixed2(const char *f, uint32_t *out)
{
    uint32_t ip = 0, fp = 0;
    int digits = 0;
    const char *p = f;
    while (is_digit(*p)) ip = ip * 10 + (uint32_t)(*p++ - '0');
    if (*p == '.') {
        p++;
        while (is_digit(*p) && digits < 2) { fp = fp * 10 + (uint32_t)(*p++ - '0'); digits++; }
        while (is_digit(*p)) p++;
    }
    if (*p != '\0') return false;
    for (; digits < 2; digits++) fp *= 10;
    *out = ip * 100u + fp;
    return true;
}

bool nmea_parse_rmc(const char *line, GpsData_t *out)
{
    out->valid = false;

    if (!nmea_verify_checksum(line)) return false;
    if (strncmp(line + 3, "RMC,", 4) != 0) return false;

    char buf[NMEA_MAX_LEN];
    size_t len = strlen(line);
    if (len >= sizeof(buf)) return false;
    memcpy(buf, line, len + 1);

    char *star = strchr(buf, '*');
    if (star == NULL) return false;
    *star = '\0';

    char *f[16];
    int n = split_fields(buf, f, 16);
    if (n < 10) return false;

    /* f[1]=time f[2]=status f[3]=lat f[4]=N/S f[5]=lon f[6]=E/W f[7]=speed f[9]=date */
    if (f[2][0] != 'A') return false;      /* V = no fix */

    GpsData_t d = {0};

    if (strlen(f[1]) < 6 || strlen(f[9]) < 6) return false;
    if (!parse_2digits(f[1], &d.hour) || !parse_2digits(f[1] + 2, &d.minute) ||
        !parse_2digits(f[1] + 4, &d.second)) return false;

    uint8_t yy;
    if (!parse_2digits(f[9], &d.day) || !parse_2digits(f[9] + 2, &d.month) ||
        !parse_2digits(f[9] + 4, &yy)) return false;
    d.year = (uint16_t)(2000 + yy);

    if (!parse_coord(f[3], f[4][0], 2, &d.lat_e6)) return false;
    if (!parse_coord(f[5], f[6][0], 3, &d.lon_e6)) return false;

    uint32_t knots_e2;
    if (!parse_fixed2(f[7], &knots_e2)) return false;
    d.speed_dkmh = (uint16_t)((knots_e2 * 1852u) / 10000u);   /* knots to 0.1 km/h */

    d.valid = true;
    *out = d;
    return true;
}
