#ifndef SD_LOG_H
#define SD_LOG_H

/* GPS log on the SD card (FatFs).
 * One file per UTC day: LOG/YYYYMMDD.BIN, made of 16-byte GpsRecord_t records.
 * Call these functions ONLY from the Mem_Access_Data task.
 */

#include <stdint.h>
#include "record.h"     /* GpsRecord_t (16 bytes, field ts = unix time UTC) */

#define SDLOG_SYNC_EVERY     10u        /* f_sync after this many records...           */
#define SDLOG_SYNC_MS        30000u     /* ...or after this time (power cut: max loss)  */
#define SDLOG_MIN_FREE_KB    (1024u)    /* below this, the oldest day file is deleted   */
#define SDLOG_MAX_RANGE_DAYS 31u        /* a history request covers 31 days at most     */

typedef struct {
    uint32_t from, to;   /* unix time range, inclusive */
    uint32_t day;        /* day being read (unix time / 86400) */
    uint32_t off;        /* byte offset inside that day file */
    uint8_t  active;     /* 1 = more records may follow */
} SdHist_t;

int      SDLOG_Init(void);                       /* mount + LOG folder. 0 = OK, else FRESULT */
int      SDLOG_IsReady(void);
int      SDLOG_SelfTest(void);                   /* write/read TEST.TXT. 0 = OK */
int      SDLOG_Append(const GpsRecord_t *r);     /* 0 = OK */
void     SDLOG_Flush(void);                      /* f_sync now */
void     SDLOG_Close(void);                      /* close the open day file */
void     SDLOG_Unmount(void);                    /* before Stop2 / power-off */

void     SDLOG_HistStart(SdHist_t *h, uint32_t from, uint32_t to);
uint16_t SDLOG_HistNext(SdHist_t *h, GpsRecord_t *out, uint16_t max);  /* records read */

#endif
