/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdio.h>
#include <string.h>
#include "hci_tl.h"
#include "hci_le.h"
#include "hci_const.h"
#include "bluenrg_gap.h"
#include "bluenrg_gap_aci.h"
#include "bluenrg_gatt_aci.h"
#include "bluenrg_hal_aci.h"
#include "bluenrg_utils.h"
#include "nmea_parser.h"
#include "record.h"
#include "track.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define SIMULATE_GPS 0   /* 1 = FAKE moving position for indoor tests. Keep 0 for real use. */
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
UART_HandleTypeDef huart4;
UART_HandleTypeDef huart1;

/* USER CODE BEGIN PV */
uint8_t gps_byte;
uint16_t gpsServHandle, gpsCharHandle, distCharHandle;
volatile uint8_t ble_connected = 0;
uint16_t ble_conn_handle = 0;
static NmeaLine_t nmea_line;
static char ready_line[NMEA_MAX_LEN];
static volatile uint8_t line_ready = 0;
static Track_t trk;
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_UART4_Init(void);
static void MX_USART1_UART_Init(void);
/* USER CODE BEGIN PFP */
void user_notify(void *pData);
void HCI_Event_CB(void *pData);
static void BLE_Setup(void);
static void BLE_SendRecord(const GpsRecord_t *r);
static void BLE_SendDistance(uint32_t meters);
static void process_fix(const GpsData_t *gps);
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_UART4_Init();
  MX_USART1_UART_Init();
  /* USER CODE BEGIN 2 */
    const char msg[] = "Bike Tracker v2: boot OK\r\n";
    HAL_UART_Transmit(&huart1, (uint8_t *)msg, sizeof(msg) - 1, 100);

    hci_init(user_notify, NULL);
    hci_reset();
    HAL_Delay(100);

    BLE_Setup();

    HAL_UART_Receive_IT(&huart4, &gps_byte, 1);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
    hci_user_evt_proc();

    static uint32_t last_fix_tick = 0;

    /* A complete NMEA line arrived from the GPS */
    if (line_ready)
    {
      GpsData_t gps;

      if (nmea_parse_rmc(ready_line, &gps))
      {
        process_fix(&gps);
        last_fix_tick = HAL_GetTick();
      }
      else if (strncmp(ready_line + 3, "RMC", 3) == 0)
      {
        const char nf[] = "NO FIX\r\n";
        HAL_UART_Transmit(&huart1, (uint8_t *)nf, sizeof(nf) - 1, 100);
      }
      line_ready = 0;
    }

    /* Signal lost for 5 s: restart the path so no phantom distance is added */
    if (trk.have && (HAL_GetTick() - last_fix_tick) > 5000)
    {
      track_lost(&trk);
    }

#if SIMULATE_GPS
    /* FAKE data for indoor tests only: moves about 10 m north every second */
    {
      static uint32_t t_sim = 0;
      static int32_t  sim_lat = 36800000;
      if ((HAL_GetTick() - t_sim) >= 1000)
      {
        t_sim = HAL_GetTick();
        sim_lat += 90;
        GpsData_t g = {0};
        uint32_t s = HAL_GetTick() / 1000u;
        g.valid = true;
        g.year = 2026; g.month = 11; g.day = 9;
        g.hour = (uint8_t)((s / 3600u) % 24u);
        g.minute = (uint8_t)((s / 60u) % 60u);
        g.second = (uint8_t)(s % 60u);
        g.lat_e6 = sim_lat;
        g.lon_e6 = 10180000;
        g.speed_dkmh = 360;               /* 36 km/h */
        process_fix(&g);
        last_fix_tick = HAL_GetTick();
      }
    }
#endif
    /* USER CODE END 3 */
  }
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  if (HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_MSI;
  RCC_OscInitStruct.MSIState = RCC_MSI_ON;
  RCC_OscInitStruct.MSICalibrationValue = 0;
  RCC_OscInitStruct.MSIClockRange = RCC_MSIRANGE_6;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_MSI;
  RCC_OscInitStruct.PLL.PLLM = 1;
  RCC_OscInitStruct.PLL.PLLN = 40;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV7;
  RCC_OscInitStruct.PLL.PLLQ = RCC_PLLQ_DIV2;
  RCC_OscInitStruct.PLL.PLLR = RCC_PLLR_DIV2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_4) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief UART4 Initialization Function
  * @param None
  * @retval None
  */
static void MX_UART4_Init(void)
{

  /* USER CODE BEGIN UART4_Init 0 */

  /* USER CODE END UART4_Init 0 */

  /* USER CODE BEGIN UART4_Init 1 */

  /* USER CODE END UART4_Init 1 */
  huart4.Instance = UART4;
  huart4.Init.BaudRate = 9600;
  huart4.Init.WordLength = UART_WORDLENGTH_8B;
  huart4.Init.StopBits = UART_STOPBITS_1;
  huart4.Init.Parity = UART_PARITY_NONE;
  huart4.Init.Mode = UART_MODE_TX_RX;
  huart4.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart4.Init.OverSampling = UART_OVERSAMPLING_16;
  huart4.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart4.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart4) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN UART4_Init 2 */

  /* USER CODE END UART4_Init 2 */

}

/**
  * @brief USART1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART1_UART_Init(void)
{

  /* USER CODE BEGIN USART1_Init 0 */

  /* USER CODE END USART1_Init 0 */

  /* USER CODE BEGIN USART1_Init 1 */

  /* USER CODE END USART1_Init 1 */
  huart1.Instance = USART1;
  huart1.Init.BaudRate = 115200;
  huart1.Init.WordLength = UART_WORDLENGTH_8B;
  huart1.Init.StopBits = UART_STOPBITS_1;
  huart1.Init.Parity = UART_PARITY_NONE;
  huart1.Init.Mode = UART_MODE_TX_RX;
  huart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart1.Init.OverSampling = UART_OVERSAMPLING_16;
  huart1.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart1.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART1_Init 2 */

  /* USER CODE END USART1_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOE_CLK_ENABLE();
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(BLE_CS_GPIO_Port, BLE_CS_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(BLE_RESET_GPIO_Port, BLE_RESET_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pins : PE2 PE3 PE4 PE5
                           PE7 PE8 PE9 PE10
                           PE11 PE12 PE13 PE14
                           PE15 PE0 PE1 */
  GPIO_InitStruct.Pin = GPIO_PIN_2|GPIO_PIN_3|GPIO_PIN_4|GPIO_PIN_5
                          |GPIO_PIN_7|GPIO_PIN_8|GPIO_PIN_9|GPIO_PIN_10
                          |GPIO_PIN_11|GPIO_PIN_12|GPIO_PIN_13|GPIO_PIN_14
                          |GPIO_PIN_15|GPIO_PIN_0|GPIO_PIN_1;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOE, &GPIO_InitStruct);

  /*Configure GPIO pin : BLE_IRQ_Pin */
  GPIO_InitStruct.Pin = BLE_IRQ_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(BLE_IRQ_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pins : PC13 PC14 PC15 PC0
                           PC1 PC2 PC3 PC4
                           PC5 PC6 PC7 PC8
                           PC9 */
  GPIO_InitStruct.Pin = GPIO_PIN_13|GPIO_PIN_14|GPIO_PIN_15|GPIO_PIN_0
                          |GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3|GPIO_PIN_4
                          |GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7|GPIO_PIN_8
                          |GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : PH0 PH1 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOH, &GPIO_InitStruct);

  /*Configure GPIO pins : PA2 PA3 PA4 PA5
                           PA6 PA7 PA9 PA10
                           PA11 PA12 PA15 */
  GPIO_InitStruct.Pin = GPIO_PIN_2|GPIO_PIN_3|GPIO_PIN_4|GPIO_PIN_5
                          |GPIO_PIN_6|GPIO_PIN_7|GPIO_PIN_9|GPIO_PIN_10
                          |GPIO_PIN_11|GPIO_PIN_12|GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pins : PB0 PB1 PB2 PB10
                           PB11 PB12 PB13 PB14
                           PB15 PB3 PB4 PB5
                           PB8 PB9 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_10
                          |GPIO_PIN_11|GPIO_PIN_12|GPIO_PIN_13|GPIO_PIN_14
                          |GPIO_PIN_15|GPIO_PIN_3|GPIO_PIN_4|GPIO_PIN_5
                          |GPIO_PIN_8|GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /*Configure GPIO pins : PD8 PD9 PD10 PD11
                           PD12 PD14 PD15 PD0
                           PD1 PD2 PD3 PD4
                           PD5 PD6 PD7 */
  GPIO_InitStruct.Pin = GPIO_PIN_8|GPIO_PIN_9|GPIO_PIN_10|GPIO_PIN_11
                          |GPIO_PIN_12|GPIO_PIN_14|GPIO_PIN_15|GPIO_PIN_0
                          |GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3|GPIO_PIN_4
                          |GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_ANALOG;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pin : BLE_CS_Pin */
  GPIO_InitStruct.Pin = BLE_CS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(BLE_CS_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : BLE_RESET_Pin */
  GPIO_InitStruct.Pin = BLE_RESET_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(BLE_RESET_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
  if (huart->Instance == UART4)
  {
    if (nmea_line_feed(&nmea_line, (char)gps_byte) && !line_ready)
    {
      strcpy(ready_line, nmea_line.buf);
      line_ready = 1;
      // --- ADD THIS LINE HERE ---
      printf("RAW GPS: %s\r\n", ready_line);
    }
    HAL_UART_Receive_IT(&huart4, &gps_byte, 1);
  }
}

void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
  if (huart->Instance == UART4)
  {
    HAL_UART_Receive_IT(&huart4, &gps_byte, 1);
  }
}

void user_notify(void *pData)
{
  HCI_Event_CB(pData);
}

/* ---------- One valid GPS fix: record, distance, BLE, log ---------- */
static void process_fix(const GpsData_t *gps)
{
  GpsRecord_t rec;
  char out[128];

  record_make(gps, &rec);
  track_update(&trk, gps);
  BLE_SendRecord(&rec);
  BLE_SendDistance((uint32_t)trk.total_m);

  int n = snprintf(out, sizeof(out),
                   "FIX ts=%lu lat=%ld lon=%ld v=%u d=%lum\r\n",
                   (unsigned long)rec.ts, (long)rec.lat_e6, (long)rec.lon_e6,
                   rec.speed_dkmh, (unsigned long)trk.total_m);
  if (n > 0) HAL_UART_Transmit(&huart1, (uint8_t *)out, (uint16_t)n, 100);
}

/* ---------- BLE application ---------- */
static const uint8_t GPS_SERV_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe0,0xf2,0x73,0xd9};
static const uint8_t GPS_CHAR_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe1,0xf2,0x73,0xd9};
static const uint8_t DIST_CHAR_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe2,0xf2,0x73,0xd9};

static void BLE_StartAdvertising(void)
{
  uint8_t local_name[] = { AD_TYPE_COMPLETE_LOCAL_NAME,
                           'B','i','k','e','T','r','a','c','k','e','r' };
  tBleStatus st = aci_gap_set_discoverable(ADV_IND, 0, 0, PUBLIC_ADDR,
                                           NO_WHITE_LIST_USE,
                                           sizeof(local_name), (char *)local_name,
                                           0, NULL, 0, 0);
  char t[32];
  int n = snprintf(t, sizeof(t), "advertise status=0x%02X\r\n", st);
  HAL_UART_Transmit(&huart1, (uint8_t *)t, (uint16_t)n, 100);
}

static void BLE_Setup(void)
{
  uint16_t gap_serv, dev_name, appearance;
  char txt[64];

  uint8_t bdaddr[6] = {0x01,0x02,0x03,0x04,0x05,0xC0};
  aci_hal_write_config_data(0x00, 6, bdaddr);
  aci_gatt_init();
  aci_gap_init_IDB05A1(GAP_PERIPHERAL_ROLE_IDB05A1, 0, 12, &gap_serv, &dev_name, &appearance);
  aci_gatt_update_char_value(gap_serv, dev_name, 0, 11, (uint8_t *)"BikeTracker");

  /* 7 attributes: 1 service + 3 for the record characteristic + 3 for the distance one */
  tBleStatus s1 = aci_gatt_add_serv(UUID_TYPE_128, GPS_SERV_UUID, PRIMARY_SERVICE, 7, &gpsServHandle);
  tBleStatus s2 = aci_gatt_add_char(gpsServHandle, UUID_TYPE_128, GPS_CHAR_UUID, 16,
                                    CHAR_PROP_NOTIFY | CHAR_PROP_READ, ATTR_PERMISSION_NONE,
                                    GATT_DONT_NOTIFY_EVENTS, 16, 0, &gpsCharHandle);
  tBleStatus s3 = aci_gatt_add_char(gpsServHandle, UUID_TYPE_128, DIST_CHAR_UUID, 4,
                                    CHAR_PROP_NOTIFY | CHAR_PROP_READ, ATTR_PERMISSION_NONE,
                                    GATT_DONT_NOTIFY_EVENTS, 16, 0, &distCharHandle);
  BLE_StartAdvertising();

  snprintf(txt, sizeof(txt), "BLE ready: serv=%02X rec=%02X dist=%02X\r\n", s1, s2, s3);
  HAL_UART_Transmit(&huart1, (uint8_t *)txt, strlen(txt), 100);
}

static void BLE_SendRecord(const GpsRecord_t *r)
{
  aci_gatt_update_char_value(gpsServHandle, gpsCharHandle, 0, 16, (uint8_t *)r);
}

static void BLE_SendDistance(uint32_t meters)
{
  aci_gatt_update_char_value(gpsServHandle, distCharHandle, 0, 4, (uint8_t *)&meters);
}

void HCI_Event_CB(void *pData)
{
  hci_uart_pckt *p = (hci_uart_pckt *)pData;
  if (p->type != HCI_EVENT_PKT) return;
  hci_event_pckt *e = (hci_event_pckt *)p->data;

  if (e->evt == EVT_DISCONN_COMPLETE)
  {
    ble_connected = 0;
    BLE_StartAdvertising();
  }
  else if (e->evt == EVT_LE_META_EVENT)
  {
    evt_le_meta_event *m = (evt_le_meta_event *)e->data;
    if (m->subevent == EVT_LE_CONN_COMPLETE)
    {
      evt_le_connection_complete *c = (evt_le_connection_complete *)m->data;
      ble_conn_handle = c->handle;
      ble_connected = 1;
    }
  }
}

void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)
{
  if (GPIO_Pin == GPIO_PIN_6)
  {
    hci_tl_lowlevel_isr();
  }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
