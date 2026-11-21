#include "hist_stream.h"
#include "ble_service.h"
#include "sd_log.h"
#include "app_log.h"
#include "bluenrg_def.h"   /* BLE_STATUS_SUCCESS, BLE_STATUS_INSUFFICIENT_RESOURCES */

#define PAGE            16u
#define FRAMES_PER_CALL 4u   /* don't keep the main loop busy too long */

typedef enum { HS_IDLE, HS_SENDING, HS_END } HsState_t;

static HsState_t   s_state = HS_IDLE;
static SdHist_t    s_h;
static GpsRecord_t s_page[PAGE];
static uint16_t    s_n, s_i;
static uint8_t     s_seq, s_status;
static uint32_t    s_count, s_bad0;

static void finish(uint8_t status)
{
    s_status = status;
    s_state = HS_END;
}

void HIST_HandleCommand(const HpCommand_t *c)
{
    switch (c->cmd) {
    case HP_CMD_HISTORY:
        s_seq = 0;
        s_count = 0;
        s_n = s_i = 0;
        s_bad0 = SDLOG_BadRecords();
        if (!SDLOG_IsReady() && SDLOG_Init() != 0) { finish(HP_ST_NO_SD); break; }
        SDLOG_HistStart(&s_h, c->from, c->to);
        App_Log("[HIST] start %lu..%lu\r\n", (unsigned long)c->from, (unsigned long)c->to);
        s_state = HS_SENDING;
        break;
    case HP_CMD_STOP:
        if (s_state != HS_IDLE) finish(HP_ST_STOPPED);
        break;
    case HP_CMD_RESET_DIST:
        break;                      /* handled in main.c (it owns the Track_t) */
    default:
        s_seq = 0; s_count = 0; s_bad0 = SDLOG_BadRecords();
        finish(HP_ST_BAD_REQUEST);
        break;
    }
}

void HIST_Process(void)
{
    uint8_t frame[HP_MAX_FRAME];

    if (s_state == HS_IDLE) return;
    if (!BLE_IsConnected()) {                     /* phone gone: drop the transfer */
        App_Log("[HIST] aborted (disconnected)\r\n");
        s_state = HS_IDLE;
        return;
    }

    for (unsigned k = 0; k < FRAMES_PER_CALL; k++) {
        if (s_state == HS_SENDING && s_i >= s_n) {           /* need the next page */
            s_n = SDLOG_HistNext(&s_h, s_page, PAGE);
            s_i = 0;
            if (s_n == 0 && !s_h.active) finish(HP_ST_OK);
            if (s_n == 0) continue;
        }

        uint8_t len;
        if (s_state == HS_SENDING) {
            len = hp_make_data(frame, s_seq, &s_page[s_i]);
        } else {                                              /* HS_END */
            uint32_t bad = SDLOG_BadRecords() - s_bad0;
            len = hp_make_end(frame, s_seq, s_count, s_status, (uint8_t)(bad > 255u ? 255u : bad));
        }

        uint8_t st = BLE_SendHistFrame(frame, len);
        if (st == BLE_STATUS_INSUFFICIENT_RESOURCES) return; /* BlueNRG full: retry next turn */
        if (st != BLE_STATUS_SUCCESS) {
            App_Log("[HIST] send error 0x%02X\r\n", st);
            s_state = HS_IDLE;
            return;
        }

        s_seq++;
        if (s_state == HS_SENDING) {
            s_i++;
            s_count++;
        } else {
            App_Log("[HIST] end: %lu records, status %u\r\n", (unsigned long)s_count, s_status);
            s_state = HS_IDLE;
            return;
        }
    }
}

bool HIST_IsBusy(void) { return s_state != HS_IDLE; }
