#ifndef BLE_SERVICE_H
#define BLE_SERVICE_H

/* BLE application (F4 + F7): moved out of main.c so a CubeMX regenerate can't break it.
 * Service ...e0f2 with 4 characteristics:
 *   e1 live record  NOTIFY|READ  16 bytes
 *   e2 distance     NOTIFY|READ   4 bytes (u32 metres)
 *   e3 control      WRITE         1..9 bytes (see hist_proto.h)
 *   e4 history      NOTIFY        8..20 bytes frames
 */

#include <stdint.h>
#include <stdbool.h>
#include "record.h"
#include "hist_proto.h"

void    BLE_Init(void);                         /* after hci_init/hci_reset, before the loop */
void    BLE_Process(void);                      /* call often: serves BlueNRG events */
bool    BLE_IsConnected(void);
void    BLE_SendRecord(const GpsRecord_t *r);   /* live */
void    BLE_SendDistance(uint32_t meters);
uint8_t BLE_SendHistFrame(const uint8_t *frame, uint8_t len);  /* returns tBleStatus (0x64 = buffers full, retry) */
bool    BLE_TakeCommand(HpCommand_t *cmd);      /* true once per command written by the app */
void    BLE_SlowAdvertising(bool slow);         /* F6: 1 s interval while the bike sleeps */

#endif
