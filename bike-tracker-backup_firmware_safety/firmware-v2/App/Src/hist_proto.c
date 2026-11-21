#include "hist_proto.h"
#include <string.h>

static uint32_t rd_u32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void wr_u32(uint8_t *p, uint32_t v)
{
    p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24);
}

bool hp_parse_command(const uint8_t *buf, uint8_t len, HpCommand_t *out)
{
    if (buf == NULL || len == 0) return false;
    memset(out, 0, sizeof(*out));
    out->cmd = buf[0];

    switch (buf[0]) {
    case HP_CMD_HISTORY:
        if (len != 9) return false;
        out->from = rd_u32(&buf[1]);
        out->to   = rd_u32(&buf[5]);
        return out->from <= out->to;
    case HP_CMD_STOP:
    case HP_CMD_RESET_DIST:
        return len == 1;
    default:
        return false;
    }
}

uint8_t hp_make_data(uint8_t *out, uint8_t seq, const GpsRecord_t *r)
{
    out[0] = HP_FRAME_DATA;
    out[1] = seq;
    memcpy(&out[2], r, sizeof(*r));           /* little-endian, packed, CRC included */
    return HP_DATA_LEN;
}

uint8_t hp_make_end(uint8_t *out, uint8_t seq, uint32_t count, uint8_t status, uint8_t bad)
{
    out[0] = HP_FRAME_END;
    out[1] = seq;
    wr_u32(&out[2], count);
    out[6] = status;
    out[7] = bad;
    return HP_END_LEN;
}
