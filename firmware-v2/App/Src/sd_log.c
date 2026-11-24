#include "sd_log.h"
#include "fatfs.h"        /* ff.h + USERPath (CubeMX) */
#include "app_log.h"
#include "timeutil.h"
#include "main.h"
#include <stdio.h>
#include <string.h>
#include "sd_spi.h"


#define REC_SIZE        ((UINT)sizeof(GpsRecord_t))
#define TS_MIN_VALID    1577836800u   /* 2020-01-01: older = no real GPS time yet */
/* CubeMX's diskio.c calls our SD_Init() only once and remembers it in this flag.
   We clear it so a re-inserted or busy card is really initialised again. */
extern Disk_drvTypeDef disk;
static FATFS    s_fs;
static FIL      s_wf;                 /* day file being written */
static FIL      s_rf;                 /* file being read */
static uint8_t  s_mounted, s_wopen;
static uint32_t s_wday = 0xFFFFFFFFu;
static uint32_t s_unsynced, s_lastSync, s_bad;

static void day_name(uint32_t day, char *out, size_t len)
{
    unsigned y, m, d;
    time_ymd_from_days(day, &y, &m, &d);
    snprintf(out, len, "LOG/%04u%02u%02u.BIN", y, m, d);   /* 8.3 name, no LFN needed */
}

static uint32_t free_kb(void)
{
    FATFS *fs;
    DWORD clust;
    if (f_getfree(USERPath, &clust, &fs) != FR_OK) return 0;
    return (uint32_t)(clust * fs->csize / 2u);
}

static void make_room(void)
{
    for (int guard = 0; guard < 64 && free_kb() < SDLOG_MIN_FREE_KB; guard++) {
        DIR dir;
        FILINFO fno;
        char oldest[13] = "";
        if (f_opendir(&dir, "LOG") != FR_OK) return;
        while (f_readdir(&dir, &fno) == FR_OK && fno.fname[0]) {
            if (fno.fattrib & AM_DIR) continue;
            if (oldest[0] == '\0' || strcmp(fno.fname, oldest) < 0) {
                strncpy(oldest, fno.fname, sizeof(oldest) - 1);
            }
        }
        f_closedir(&dir);
        if (oldest[0] == '\0') return;

        char path[20];
        snprintf(path, sizeof(path), "LOG/%s", oldest);
        if (s_wopen) SDLOG_Close();
        App_Log("[SD] card full: delete %s\r\n", path);
        if (f_unlink(path) != FR_OK) return;
    }
}

int SDLOG_Init(void)
{
    disk.is_initialized[0] = 0;     /* force FatFs to call SD_Init() again */
    SD_Deinit();


    s_mounted = 0;
    s_wopen = 0;
    s_wday = 0xFFFFFFFFu;

    FRESULT fr = f_mount(&s_fs, USERPath, 1);              /* 1 = mount now -> SD_Init() */
    if (fr != FR_OK) { App_Log("[SD] mount error %d\r\n", fr); return fr; }
    fr = f_mkdir("LOG");
    if (fr != FR_OK && fr != FR_EXIST) { App_Log("[SD] mkdir LOG error %d\r\n", fr); return fr; }

    s_mounted = 1;
    s_lastSync = HAL_GetTick();
    make_room();
    App_Log("[SD] mounted, free %lu KB\r\n", (unsigned long)free_kb());
    return 0;
}

int      SDLOG_IsReady(void)    { return s_mounted; }
uint32_t SDLOG_BadRecords(void) { return s_bad; }

void SDLOG_Unmount(void)
{
    SDLOG_Close();
    if (s_mounted) (void)f_mount(NULL, USERPath, 0);
    s_mounted = 0;
    disk.is_initialized[0] = 0;     /* next mount = new card initialisation */
    SD_Deinit();
}

int SDLOG_SelfTest(void)
{
    static const char msg[] = "BikeTracker SD test 123\r\n";
    char back[sizeof(msg)] = {0};
    UINT n;
    FRESULT fr;

    if (!s_mounted) return -1;
    fr = f_open(&s_rf, "TEST.TXT", FA_CREATE_ALWAYS | FA_WRITE);
    if (fr != FR_OK) { App_Log("[SD] test open(w) %d\r\n", fr); return fr; }
    fr = f_write(&s_rf, msg, sizeof(msg) - 1, &n);
    f_close(&s_rf);
    if (fr != FR_OK || n != sizeof(msg) - 1) { App_Log("[SD] test write %d\r\n", fr); return -2; }

    fr = f_open(&s_rf, "TEST.TXT", FA_READ);
    if (fr != FR_OK) { App_Log("[SD] test open(r) %d\r\n", fr); return fr; }
    fr = f_read(&s_rf, back, sizeof(msg) - 1, &n);
    f_close(&s_rf);
    if (fr != FR_OK || n != sizeof(msg) - 1 || memcmp(msg, back, n) != 0) {
        App_Log("[SD] test read/compare failed %d\r\n", fr);
        return -3;
    }
    App_Log("[SD] self test OK\r\n");
    return 0;
}

/* After a power cut: cut a half-written record, then drop broken records at the end */
static void repair_tail(const char *name)
{
    FSIZE_t size = f_size(&s_wf);
    FSIZE_t good = size - (size % REC_SIZE);

    while (good >= REC_SIZE) {                              /* walk back over bad CRCs */
        GpsRecord_t r;
        UINT br;
        if (f_lseek(&s_wf, good - REC_SIZE) != FR_OK) break;
        if (f_read(&s_wf, &r, REC_SIZE, &br) != FR_OK || br != REC_SIZE) break;
        if (record_valid(&r)) break;
        good -= REC_SIZE;
    }
    if (good != size) {
        if (f_lseek(&s_wf, good) == FR_OK) (void)f_truncate(&s_wf);
        App_Log("[SD] %s repaired: %lu -> %lu bytes\r\n", name, (unsigned long)size, (unsigned long)good);
    }
}

static int open_day(uint32_t day)
{
    if (s_wopen && s_wday == day) return 0;
    SDLOG_Close();

    char name[20];
    day_name(day, name, sizeof(name));
    FRESULT fr = f_open(&s_wf, name, FA_OPEN_ALWAYS | FA_READ | FA_WRITE);
    if (fr != FR_OK) { App_Log("[SD] open %s error %d\r\n", name, fr); return fr; }

    repair_tail(name);
    fr = f_lseek(&s_wf, f_size(&s_wf));                    /* append at the end */
    if (fr != FR_OK) { f_close(&s_wf); return fr; }

    s_wopen = 1;
    s_wday = day;
    App_Log("[SD] logging to %s (%lu records)\r\n", name, (unsigned long)(f_size(&s_wf) / REC_SIZE));
    make_room();
    return 0;
}

int SDLOG_Append(const GpsRecord_t *r)
{
    if (!s_mounted) return -1;
    if (r->ts < TS_MIN_VALID) return -2;

    int err = open_day(r->ts / 86400u);
    if (err) goto fail;

    UINT bw;
    FRESULT fr = f_write(&s_wf, r, REC_SIZE, &bw);
    if (fr != FR_OK || bw != REC_SIZE) { err = (fr != FR_OK) ? (int)fr : -3; goto fail; }

    s_unsynced++;
    if (s_unsynced >= SDLOG_SYNC_EVERY || (HAL_GetTick() - s_lastSync) >= SDLOG_SYNC_MS) SDLOG_Flush();
    return 0;

fail:
    App_Log("[SD] write error %d -> unmount\r\n", err);
    SDLOG_Unmount();
    return err;
}

void SDLOG_Flush(void)
{
    if (s_wopen) (void)f_sync(&s_wf);
    s_unsynced = 0;
    s_lastSync = HAL_GetTick();
}

void SDLOG_Close(void)
{
    if (s_wopen) (void)f_close(&s_wf);
    s_wopen = 0;
    s_wday = 0xFFFFFFFFu;
    s_unsynced = 0;
}

void SDLOG_HistStart(SdHist_t *h, uint32_t from, uint32_t to)
{
    if (to < from) { uint32_t t = to; to = from; from = t; }
    const uint32_t maxSpan = SDLOG_MAX_RANGE_DAYS * 86400u;
    if (to - from > maxSpan) from = to - maxSpan;

    h->from = from;
    h->to = to;
    h->day = from / 86400u;
    h->off = 0;
    h->active = 1;
}

uint16_t SDLOG_HistNext(SdHist_t *h, GpsRecord_t *out, uint16_t max)
{
    uint16_t n = 0;
    if (!h->active || !s_mounted || max == 0) return 0;

    SDLOG_Close();   /* FS_LOCK: a file open for writing can't be opened again */

    const uint32_t lastDay = h->to / 86400u;
    while (h->day <= lastDay) {
        char name[20];
        day_name(h->day, name, sizeof(name));
        if (f_open(&s_rf, name, FA_READ) == FR_OK) {
            if (f_lseek(&s_rf, h->off) == FR_OK) {
                while (n < max) {
                    GpsRecord_t r;
                    UINT br;
                    if (f_read(&s_rf, &r, REC_SIZE, &br) != FR_OK || br != REC_SIZE) break;
                    h->off += REC_SIZE;
                    if (!record_valid(&r)) { s_bad++; continue; }   /* CRC check */
                    if (r.ts >= h->from && r.ts <= h->to) out[n++] = r;
                }
            }
            f_close(&s_rf);
            if (n >= max) return n;
        }
        h->day++;
        h->off = 0;
    }
    h->active = 0;
    return n;
}
