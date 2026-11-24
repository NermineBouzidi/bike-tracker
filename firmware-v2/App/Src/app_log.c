#include "app_log.h"
#include "main.h"
#include <stdarg.h>
#include <stdio.h>

extern UART_HandleTypeDef huart1;

#if APP_LOG_USE_RTOS
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
static SemaphoreHandle_t s_mtx;
void App_LogInitRtos(void) { s_mtx = xSemaphoreCreateMutex(); }
#else
void App_LogInitRtos(void) { }
#endif

void App_Log(const char *fmt, ...)
{
    char b[128];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(b, sizeof(b), fmt, ap);
    va_end(ap);
    if (n <= 0) return;
    if (n > (int)sizeof(b) - 1) n = (int)sizeof(b) - 1;

#if APP_LOG_USE_RTOS
    const int lock = s_mtx && (xTaskGetSchedulerState() == taskSCHEDULER_RUNNING);
    if (lock) xSemaphoreTake(s_mtx, portMAX_DELAY);
#endif
    HAL_UART_Transmit(&huart1, (uint8_t *)b, (uint16_t)n, 100);
#if APP_LOG_USE_RTOS
    if (lock) xSemaphoreGive(s_mtx);
#endif
}
