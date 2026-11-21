#ifndef SD_SPI_H
#define SD_SPI_H

/* Low-level SD card driver over SPI1 (MH-SD module).
 * Pins: SCK PA5 (D13), MISO PA6 (D12, pull-up), MOSI PA7 (D11), CS PA2 (D10, label SD_CS).
 * Used only by FatFs (user_diskio.c). Do not call it from other tasks.
 */

#include <stdint.h>

/* card types returned by SD_GetType() */
#define SD_TYPE_NONE   0u
#define SD_TYPE_MMC    1u
#define SD_TYPE_SDV1   2u
#define SD_TYPE_SDV2   3u   /* SDSC v2, byte addressing */
#define SD_TYPE_SDHC   4u   /* SDHC/SDXC, block addressing (most cards today) */

int      SD_Init(void);                                         /* 0 = OK */
int      SD_IsReady(void);
int      SD_Read(uint8_t *buf, uint32_t sector, uint32_t count);  /* 0 = OK, 512-byte sectors */
int      SD_Write(const uint8_t *buf, uint32_t sector, uint32_t count);
int      SD_Sync(void);                                         /* wait until the card is not busy */
uint32_t SD_GetSectorCount(void);                               /* 0 = error */
uint8_t  SD_GetType(void);
uint8_t  SD_LastCmd0(void);                                     /* debug: answer to CMD0, must be 0x01 */
void     SD_Deinit(void);                                       /* before Stop2 / module power-off */

#endif
