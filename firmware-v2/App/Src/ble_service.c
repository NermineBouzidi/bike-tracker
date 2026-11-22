#include "ble_service.h"
#include "main.h"
#include <string.h>
#include "app_rtos.h"
#include "hci.h"
#include "hci_tl.h"
#include "hci_le.h"
#include "hci_const.h"
#include "bluenrg_gap.h"
#include "bluenrg_gap_aci.h"
#include "bluenrg_gatt_aci.h"
#include "bluenrg_hal_aci.h"
#include "bluenrg_utils.h"

static uint16_t gpsServHandle, gpsCharHandle, distCharHandle;
static volatile uint8_t ble_connected = 0;
static uint16_t ble_conn_handle = 0;

static const uint8_t GPS_SERV_UUID[16]  = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe0,0xf2,0x73,0xd9};
static const uint8_t GPS_CHAR_UUID[16]  = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe1,0xf2,0x73,0xd9};
static const uint8_t DIST_CHAR_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe2,0xf2,0x73,0xd9};

static void BLE_StartAdvertising(void)
{
  uint8_t local_name[] = { AD_TYPE_COMPLETE_LOCAL_NAME,
                           'B','i','k','e','T','r','a','c','k','e','r' };
  tBleStatus st = aci_gap_set_discoverable(ADV_IND, 0, 0, PUBLIC_ADDR,
                                           NO_WHITE_LIST_USE,
                                           sizeof(local_name), (char *)local_name,
                                           0, NULL, 0, 0);
  App_Log("advertise status=0x%02X\r\n", st);
}

static void HCI_Event_CB(void *pData)
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

static void user_notify(void *pData)
{
  HCI_Event_CB(pData);
}

void BLE_Init(void)
{
  uint16_t gap_serv, dev_name, appearance;

  hci_init(user_notify, NULL);
  hci_reset();
  HAL_Delay(100);

  /* hci_tl_lowlevel_init() puts EXTI9_5 at priority 0, above the system tick.
     Put it back below the tick, so that the SPI time-outs inside the interrupt still expire. */
  HAL_NVIC_SetPriority(EXTI9_5_IRQn, 6, 0);
  HAL_NVIC_EnableIRQ(EXTI9_5_IRQn);

  uint8_t bdaddr[6] = {0x01,0x02,0x03,0x04,0x05,0xC0};
  tBleStatus a = aci_hal_write_config_data(0x00, 6, bdaddr);
  tBleStatus b = aci_gatt_init();
  tBleStatus c = aci_gap_init_IDB05A1(GAP_PERIPHERAL_ROLE_IDB05A1, 0, 12,
                                      &gap_serv, &dev_name, &appearance);
  tBleStatus d = aci_gatt_update_char_value(gap_serv, dev_name, 0, 11, (uint8_t *)"BikeTracker");
  App_Log("BLE init: hal=%02X gatt=%02X gap=%02X name=%02X\r\n", a, b, c, d);

  /* 7 attributes: 1 service + 3 per characteristic x 2 */
  tBleStatus s1 = aci_gatt_add_serv(UUID_TYPE_128, GPS_SERV_UUID, PRIMARY_SERVICE, 7, &gpsServHandle);
  tBleStatus s2 = aci_gatt_add_char(gpsServHandle, UUID_TYPE_128, GPS_CHAR_UUID, 16,
                                    CHAR_PROP_NOTIFY | CHAR_PROP_READ, ATTR_PERMISSION_NONE,
                                    GATT_DONT_NOTIFY_EVENTS, 16, 0, &gpsCharHandle);
  tBleStatus s3 = aci_gatt_add_char(gpsServHandle, UUID_TYPE_128, DIST_CHAR_UUID, 4,
                                    CHAR_PROP_NOTIFY | CHAR_PROP_READ, ATTR_PERMISSION_NONE,
                                    GATT_DONT_NOTIFY_EVENTS, 16, 0, &distCharHandle);
  BLE_StartAdvertising();
  App_Log("BLE ready: serv=%02X rec=%02X dist=%02X\r\n", s1, s2, s3);
}

void BLE_SendRecord(const GpsRecord_t *r)
{
  aci_gatt_update_char_value(gpsServHandle, gpsCharHandle, 0, 16, (uint8_t *)r);
}

void BLE_SendDistance(uint32_t meters)
{
  aci_gatt_update_char_value(gpsServHandle, distCharHandle, 0, 4, (uint8_t *)&meters);
}

void BLE_ProcessEvents(void)
{
  hci_user_evt_proc();
}

uint8_t BLE_IsConnected(void)
{
  return ble_connected;
}
