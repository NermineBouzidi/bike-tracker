#ifndef SD_LOG_H
#define SD_LOG_H

/* GPS log on the SD card (FatFs) - F3.
 * One file per UTC day: LOG/YYYYMMDD.BIN, made of 16-byte GpsRecord_t records
 * (ts, lat, lon, speed, CRC-16). The CRC is checked when reading and after a power cut.
 * Simple loop: call from the main loop only. F5: call from Mem_Access_Data only.
 */

#include <stdint.h>
#include "record.h"

#define SDLOG_SYNC_EVERY     10u        /* f_sync after this many records...           */
#define SDLOG_SYNC_MS        30000u     /* ...or after this time (power cut: max loss)  */
#define SDLOG_MIN_FREE_KB    1024u      /* below this, the oldest day file is deleted   */
#define SDLOG_MAX_RANGE_DAYS 31u        /* a history request covers 31 days at most     */

typedef struct {
    uint32_t from, to;   /* unix time range, inclusive */
    uint32_t day;        /* day being read (unix time / 86400) */
    uint32_t off;        /* byte offset inside that day file */
    uint8_t  active;     /* 1 = more records may follow */
} SdHist_t;

int      SDLOG_Init(void);                       /* mount + LOG folder. 0 = OK */
int      SDLOG_IsReady(void);
int      SDLOG_SelfTest(void);                   /* write/read TEST.TXT. 0 = OK */
int      SDLOG_Append(const GpsRecord_t *r);     /* 0 = OK */
void     SDLOG_Flush(void);
void     SDLOG_Close(void);
void     SDLOG_Unmount(void);                    /* before Stop2 */
uint32_t SDLOG_BadRecords(void);                 /* CRC errors seen while reading */

void     SDLOG_HistStart(SdHist_t *h, uint32_t from, uint32_t to);
uint16_t SDLOG_HistNext(SdHist_t *h, GpsRecord_t *out, uint16_t max);

#endif
