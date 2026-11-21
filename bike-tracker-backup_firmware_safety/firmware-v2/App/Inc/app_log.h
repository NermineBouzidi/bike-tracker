#ifndef APP_LOG_H
#define APP_LOG_H

/* printf-like log to USART1 (Hercules, 115200).
 * Never call it from an interrupt.
 * F5 (FreeRTOS): delete App_Log from app_rtos.c and keep this one; it uses a mutex
 * automatically once APP_LOG_USE_RTOS is 1 and App_LogInitRtos() was called.
 */

#ifndef APP_LOG_USE_RTOS
#define APP_LOG_USE_RTOS 0
#endif

void App_Log(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
void App_LogInitRtos(void);   /* F5 only: create the mutex before the scheduler starts */

#endif
