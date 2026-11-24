#ifndef HIST_PROTO_H
#define HIST_PROTO_H

/* BLE history protocol (F4). Pure C, no HAL: tested on the PC (Tests/test_all.c).
 * Full description for the app: docs/BLE_PROTOCOL.md
 *
 * Control characteristic (app WRITES, max 9 bytes):
 *   0x01 HISTORY  [0x01][from u32 LE][to u32 LE]   unix UTC, inclusive
 *   0x02 STOP     [0x02]                           stop a history transfer
 *   0x03 RESET_D  [0x03]                           reset the trip distance
 *
 * History characteristic (board NOTIFIES, max 20 bytes = default BLE MTU 23 - 3):
 *   DATA  [0x10][seq u8][GpsRecord_t 16 bytes]                  = 18 bytes
 *   END   [0x11][seq u8][count u32 LE][status u8][bad u8]       = 8 bytes
 *   seq goes 0,1,2...255,0... over all frames of one transfer: a gap = a lost frame.
 */

#include <stdint.h>
#include <stdbool.h>
#include "record.h"

#define HP_CMD_HISTORY      0x01u
#define HP_CMD_STOP         0x02u
#define HP_CMD_RESET_DIST   0x03u

#define HP_FRAME_DATA       0x10u
#define HP_FRAME_END        0x11u

#define HP_ST_OK            0u    /* all records of the range were sent */
#define HP_ST_NO_SD         1u    /* no SD card: nothing sent */
#define HP_ST_STOPPED       2u    /* the app sent STOP */
#define HP_ST_BAD_REQUEST   3u

#define HP_MAX_FRAME        20u
#define HP_DATA_LEN         18u
#define HP_END_LEN          8u

typedef struct {
    uint8_t  cmd;
    uint32_t from, to;
} HpCommand_t;

bool    hp_parse_command(const uint8_t *buf, uint8_t len, HpCommand_t *out);
uint8_t hp_make_data(uint8_t *out, uint8_t seq, const GpsRecord_t *r);
uint8_t hp_make_end(uint8_t *out, uint8_t seq, uint32_t count, uint8_t status, uint8_t bad);

#endif
