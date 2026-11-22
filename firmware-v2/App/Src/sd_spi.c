/* SD card over SPI - based on the classic ChaN MMC/SDC SPI method.
 * Start at <= 400 kHz (prescaler 256: 80 MHz / 256 = 312 kHz),
 * then 10 MHz (prescaler 8) after the card is initialised.
 */
#include "sd_spi.h"
#include "main.h"      /* SD_CS_Pin, SD_CS_GPIO_Port (CubeMX label "SD_CS" on PA2) */
#include <string.h>

extern SPI_HandleTypeDef hspi1;
#define SD_SPI (&hspi1)

/* SD commands (ACMD = 0x80 | n : sent after CMD55) */
#define CMD0    (0u)
#define CMD1    (1u)
#define CMD8    (8u)
#define CMD9    (9u)
#define CMD12   (12u)
#define CMD16   (16u)
#define CMD17   (17u)
#define CMD18   (18u)
#define CMD24   (24u)
#define CMD25   (25u)
#define CMD55   (55u)
#define CMD58   (58u)
#define ACMD23  (0x80u | 23u)
#define ACMD41  (0x80u | 41u)

static uint8_t s_type  = SD_TYPE_NONE;
static uint8_t s_ready = 0;
static uint8_t s_cmd0  = 0xFF;

static const uint8_t s_ff[512] = { [0 ... 511] = 0xFF };  /* sent while receiving */
static uint8_t s_dummy[512];                              /* received while sending */

/* ---------------- SPI helpers ---------------- */
static inline void cs_low(void)  { HAL_GPIO_WritePin(SD_CS_GPIO_Port, SD_CS_Pin, GPIO_PIN_RESET); }
static inline void cs_high(void) { HAL_GPIO_WritePin(SD_CS_GPIO_Port, SD_CS_Pin, GPIO_PIN_SET); }

static uint8_t xchg(uint8_t b)
{
    uint8_t r = 0xFF;
    (void)HAL_SPI_TransmitReceive(SD_SPI, &b, &r, 1, 50);
    return r;
}

static void rx_bytes(uint8_t *buf, uint16_t n)
{
    (void)HAL_SPI_TransmitReceive(SD_SPI, (uint8_t *)s_ff, buf, n, 200);
}

static void tx_bytes(const uint8_t *buf, uint16_t n)
{
    (void)HAL_SPI_TransmitReceive(SD_SPI, (uint8_t *)buf, s_dummy, n, 200);
}

static void set_prescaler(uint32_t presc)
{
    __HAL_SPI_DISABLE(SD_SPI);                      /* BR can change only when SPE = 0 */
    MODIFY_REG(SD_SPI->Instance->CR1, SPI_CR1_BR, presc);
    SD_SPI->Init.BaudRatePrescaler = presc;         /* HAL enables SPE again at the next transfer */
}

static int wait_ready(uint32_t ms)                  /* the card answers 0xFF when not busy */
{
    uint32_t t0 = HAL_GetTick();
    do {
        if (xchg(0xFF) == 0xFF) return 1;
    } while ((HAL_GetTick() - t0) < ms);
    return 0;
}

static void deselect(void)
{
    cs_high();
    (void)xchg(0xFF);                               /* one extra clock to release MISO */
}

static int select(void)
{
    cs_low();
    (void)xchg(0xFF);
    if (wait_ready(500)) return 1;
    deselect();
    return 0;
}

static int rx_datablock(uint8_t *buf, uint16_t n)
{
    uint8_t token;
    uint32_t t0 = HAL_GetTick();
    do {
        token = xchg(0xFF);
    } while (token == 0xFF && (HAL_GetTick() - t0) < 200);
    if (token != 0xFE) return 0;                    /* 0xFE = start of data */
    rx_bytes(buf, n);
    (void)xchg(0xFF);                               /* CRC (ignored) */
    (void)xchg(0xFF);
    return 1;
}

static int tx_datablock(const uint8_t *buf, uint8_t token)
{
    if (!wait_ready(500)) return 0;
    (void)xchg(token);
    if (token != 0xFD) {                            /* 0xFD = stop token, no data */
        tx_bytes(buf, 512);
        (void)xchg(0xFF);                           /* dummy CRC */
        (void)xchg(0xFF);
        uint8_t resp = xchg(0xFF);
        if ((resp & 0x1F) != 0x05) return 0;        /* 0x05 = data accepted */
    }
    return 1;
}

static uint8_t send_cmd(uint8_t cmd, uint32_t arg)
{
    uint8_t res;

    if (cmd & 0x80u) {                              /* ACMD: send CMD55 first */
        cmd &= 0x7Fu;
        res = send_cmd(CMD55, 0);
        if (res > 1) return res;
    }

    if (cmd != CMD12) {
        deselect();
        if (!select()) return 0xFF;
    }

    (void)xchg(0x40u | cmd);
    (void)xchg((uint8_t)(arg >> 24));
    (void)xchg((uint8_t)(arg >> 16));
    (void)xchg((uint8_t)(arg >> 8));
    (void)xchg((uint8_t)arg);
    uint8_t crc = 0x01;                             /* CRC is only checked for CMD0 and CMD8 */
    if (cmd == CMD0) crc = 0x95;
    if (cmd == CMD8) crc = 0x87;
    (void)xchg(crc);

    if (cmd == CMD12) (void)xchg(0xFF);             /* skip a stuff byte */

    uint8_t n = 10;                                 /* R1 arrives within 8 bytes */
    do {
        res = xchg(0xFF);
    } while ((res & 0x80u) && --n);
    return res;
}

/* ---------------- Public API ---------------- */
int SD_Init(void)
{
    uint8_t ocr[4];
    uint8_t type = SD_TYPE_NONE;

    s_ready = 0;
    set_prescaler(SPI_BAUDRATEPRESCALER_256);       /* 312 kHz */

    cs_high();
    for (int i = 0; i < 10; i++) (void)xchg(0xFF);  /* >= 74 clocks with CS high */

    s_cmd0 = send_cmd(CMD0, 0);
    if (s_cmd0 == 1) {                              /* card in idle state */
        uint32_t t0 = HAL_GetTick();
        if (send_cmd(CMD8, 0x1AA) == 1) {           /* SD v2 */
            for (int i = 0; i < 4; i++) ocr[i] = xchg(0xFF);
            if (ocr[2] == 0x01 && ocr[3] == 0xAA) { /* card works at 2.7-3.6 V */
                while ((HAL_GetTick() - t0) < 1000 && send_cmd(ACMD41, 1UL << 30)) { }
                if ((HAL_GetTick() - t0) < 1000 && send_cmd(CMD58, 0) == 0) {
                    for (int i = 0; i < 4; i++) ocr[i] = xchg(0xFF);
                    type = (ocr[0] & 0x40) ? SD_TYPE_SDHC : SD_TYPE_SDV2;
                }
            }
        } else {                                    /* SD v1 or MMC */
            uint8_t cmd;
            if (send_cmd(ACMD41, 0) <= 1) { type = SD_TYPE_SDV1; cmd = ACMD41; }
            else                          { type = SD_TYPE_MMC;  cmd = CMD1;   }
            while ((HAL_GetTick() - t0) < 1000 && send_cmd(cmd, 0)) { }
            if ((HAL_GetTick() - t0) >= 1000 || send_cmd(CMD16, 512) != 0) type = SD_TYPE_NONE;
        }
    }
    deselect();

    s_type = type;
    if (type == SD_TYPE_NONE) return -1;

    set_prescaler(SPI_BAUDRATEPRESCALER_8);         /* 10 MHz */
    s_ready = 1;
    return 0;
}

int SD_IsReady(void)      { return s_ready; }
uint8_t SD_GetType(void)  { return s_type; }
uint8_t SD_LastCmd0(void) { return s_cmd0; }

int SD_Read(uint8_t *buf, uint32_t sector, uint32_t count)
{
    if (!s_ready || count == 0) return -1;
    if (s_type != SD_TYPE_SDHC) sector *= 512u;     /* byte address on old cards */

    if (count == 1) {
        if (send_cmd(CMD17, sector) == 0 && rx_datablock(buf, 512)) count = 0;
    } else {
        if (send_cmd(CMD18, sector) == 0) {
            do {
                if (!rx_datablock(buf, 512)) break;
                buf += 512;
            } while (--count);
            (void)send_cmd(CMD12, 0);               /* stop reading */
        }
    }
    deselect();
    return count ? -1 : 0;
}

int SD_Write(const uint8_t *buf, uint32_t sector, uint32_t count)
{
    if (!s_ready || count == 0) return -1;
    if (s_type != SD_TYPE_SDHC) sector *= 512u;

    if (count == 1) {
        if (send_cmd(CMD24, sector) == 0 && tx_datablock(buf, 0xFE)) count = 0;
    } else {
        if (s_type != SD_TYPE_MMC) (void)send_cmd(ACMD23, count);  /* pre-erase hint */
        if (send_cmd(CMD25, sector) == 0) {
            do {
                if (!tx_datablock(buf, 0xFC)) break;
                buf += 512;
            } while (--count);
            if (!tx_datablock(NULL, 0xFD)) count = 1;  /* stop token */
        }
    }
    deselect();
    return count ? -1 : 0;
}

int SD_Sync(void)
{
    if (!s_ready) return -1;
    int ok = select();
    deselect();
    return ok ? 0 : -1;
}

uint32_t SD_GetSectorCount(void)
{
    uint8_t csd[16];
    uint32_t count = 0;

    if (!s_ready) return 0;
    if (send_cmd(CMD9, 0) == 0 && rx_datablock(csd, 16)) {
        if ((csd[0] >> 6) == 1) {                   /* CSD v2 (SDHC/SDXC) */
            uint32_t csize = csd[9] + ((uint32_t)csd[8] << 8) + ((uint32_t)(csd[7] & 63) << 16) + 1;
            count = csize << 10;
        } else {                                    /* CSD v1 */
            uint8_t n = (uint8_t)((csd[5] & 15) + ((csd[10] & 128) >> 7) + ((csd[9] & 3) << 1) + 2);
            uint32_t csize = (csd[8] >> 6) + ((uint32_t)csd[7] << 2) + ((uint32_t)(csd[6] & 3) << 10) + 1;
            count = csize << (n - 9);
        }
    }
    deselect();
    return count;
}

void SD_Deinit(void)
{
    deselect();
    s_ready = 0;
    s_type = SD_TYPE_NONE;
}
