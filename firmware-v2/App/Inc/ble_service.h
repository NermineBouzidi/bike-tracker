#ifndef BLE_SERVICE_H
#define BLE_SERVICE_H

#include <stdint.h>
#include "record.h"

void    BLE_Init(void);                          /* stack + service + advertising, before the scheduler starts */
void    BLE_SendRecord(const GpsRecord_t *r);    /* 16-byte record */
void    BLE_SendDistance(uint32_t meters);       /* 4 bytes */
void    BLE_ProcessEvents(void);                 /* serves the BlueNRG events */
uint8_t BLE_IsConnected(void);

#endif
