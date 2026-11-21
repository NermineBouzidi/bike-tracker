#ifndef HIST_STREAM_H
#define HIST_STREAM_H

/* F4: sends a history range from the SD card over BLE without blocking.
 * Simple loop: call HIST_Process() at every turn of the main loop.
 * It reads 16 records at a time and sends as many frames as the BlueNRG accepts;
 * when its buffers are full it returns and tries again at the next turn,
 * so GPS logging and live data keep running during a transfer.
 */
#include <stdint.h>
#include <stdbool.h>
#include "hist_proto.h"

void HIST_HandleCommand(const HpCommand_t *c);   /* HISTORY / STOP / bad request */
void HIST_Process(void);
bool HIST_IsBusy(void);                          /* F6: don't sleep during a transfer */

#endif
