#ifndef POWER_H
#define POWER_H

/* F6 low power helpers.
 * Motion source (ask your supervisor which one counts):
 *   MOTION_USE_LSM6DSL 0 : dynamo signal on an EXTI pin (label MOTION_IN)  <- slides
 *   MOTION_USE_LSM6DSL 1 : onboard accelerometer LSM6DSL, INT1 = PD11, I2C2 (PB10/PB11)
 * GPS power:
 *   GPS_EN label exists in CubeMX -> a GPIO drives a MOSFET / the GPS EN pin
 *   otherwise                     -> UBX "backup mode" command (u-blox modules only)
 */

#include <stdint.h>
#include <stdbool.h>

#ifndef MOTION_USE_LSM6DSL
#define MOTION_USE_LSM6DSL 1
#endif
#define MOTION_IDLE_MS 30000u    /* 30 s without motion -> sleep */

void     Motion_Init(void);                  /* LSM6DSL: configure the wake-up interrupt */
void     Motion_FromISR(void);               /* call from HAL_GPIO_EXTI_Callback */
bool     Motion_TakeEvent(void);             /* true once after each motion interrupt */
uint32_t Motion_IdleMs(void);                /* time since the last motion */

void     GPS_PowerOn(void);
void     GPS_PowerOff(void);

void     Power_EnterStop2(void);             /* returns after a wake-up interrupt, clocks restored */

#endif
