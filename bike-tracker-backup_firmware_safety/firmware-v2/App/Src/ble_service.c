#include "ble_service.h"
#include "main.h"
#include "app_log.h"
#include <string.h>
#include "hci.h"
#include "hci_tl.h"
#include "hci_le.h"
#include "hci_const.h"
#include "bluenrg_gap.h"
#include "bluenrg_gap_aci.h"
#include "bluenrg_gatt_aci.h"
#include "bluenrg_hal_aci.h"
#include "bluenrg_aci_const.h"
#include "bluenrg_utils.h"

#define ADV_FAST   0u                      /* 0 = BlueNRG default interval */
#define ADV_SLOW   (1000u * 1000u / 625u)  /* 1 s in 0.625 ms units */

static const uint8_t SERV_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe0,0xf2,0x73,0xd9};
static const uint8_t LIVE_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe1,0xf2,0x73,0xd9};
static const uint8_t DIST_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe2,0xf2,0x73,0xd9};
static const uint8_t CTRL_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe3,0xf2,0x73,0xd9};
static const uint8_t HIST_UUID[16] = {0x66,0x9a,0x0c,0x20,0x00,0x08,0x96,0x9e,0xe2,0x11,0x9e,0xb1,0xe4,0xf2,0x73,0xd9};

static uint16_t s_serv, s_live, s_dist, s_ctrl, s_hist;
static volatile bool s_connected;
static volatile bool s_needReinit;
static uint16_t s_advInterval = ADV_FAST;

static HpCommand_t s_cmd;
static volatile bool s_cmdPending;

/* ---------------- Advertising ---------------- */
static void start_advertising(void)
{
    uint8_t name[] = { AD_TYPE_COMPLETE_LOCAL_NAME, 'B','i','k','e','T','r','a','c','k','e','r' };
    tBleStatus st = aci_gap_set_discoverable(ADV_IND, s_advInterval, s_advInterval, PUBLIC_ADDR,
                                             NO_WHITE_LIST_USE, sizeof(name), (char *)name,
                                             0, NULL, 0, 0);
    App_Log("[BLE] advertise status=0x%02X\r\n", st);
}

void BLE_SlowAdvertising(bool slow)
{
    uint16_t want = slow ? (uint16_t)ADV_SLOW : (uint16_t)ADV_FAST;
    if (want == s_advInterval) return;
    s_advInterval = want;
    if (!s_connected) {                   /* restart advertising with the new interval */
        (void)aci_gap_set_non_discoverable();
        start_advertising();
    }
}

/* ---------------- Unique address (F7) ---------------- */
static void make_address(uint8_t addr[6])
{
    /* 96-bit unique ID of this STM32 -> 40 bits. Top byte kept at 0xC0 like before. */
    uint32_t w0 = HAL_GetUIDw0(), w1 = HAL_GetUIDw1(), w2 = HAL_GetUIDw2();
    uint32_t a = w0 ^ (w2 << 7) ^ (w2 >> 25);
    uint32_t b = w1 ^ (w2 >> 9);
    addr[0] = (uint8_t)a;
    addr[1] = (uint8_t)(a >> 8);
    addr[2] = (uint8_t)(a >> 16);
    addr[3] = (uint8_t)(a >> 24);
    addr[4] = (uint8_t)(b ^ (b >> 8) ^ (b >> 16) ^ (b >> 24));
    addr[5] = 0xC0;
}

/* ---------------- Events ---------------- */
static void on_attribute_modified(const evt_gatt_attr_modified_IDB05A1 *am)
{
    if (am->attr_handle == (uint16_t)(s_ctrl + 1u)) {      /* +1 = value of the control char */
        HpCommand_t c;
        if (hp_parse_command(am->att_data, am->data_length, &c)) {
            s_cmd = c;
            s_cmdPending = true;
        } else {
            s_cmd.cmd = 0xFF;                               /* bad request: answered with END status 3 */
            s_cmdPending = true;
        }
    }
}

static void hci_event_cb(void *pData)
{
    hci_uart_pckt *p = (hci_uart_pckt *)pData;
    if (p->type != HCI_EVENT_PKT) return;
    hci_event_pckt *e = (hci_event_pckt *)p->data;

    switch (e->evt) {
    case EVT_DISCONN_COMPLETE:
        s_connected = false;
        App_Log("[BLE] disconnected\r\n");
        start_advertising();                                /* clean reconnection */
        break;

    case EVT_LE_META_EVENT: {
        evt_le_meta_event *m = (evt_le_meta_event *)e->data;
        if (m->subevent == EVT_LE_CONN_COMPLETE) {
            s_connected = true;
            App_Log("[BLE] connected\r\n");
        }
        break;
    }

    case EVT_VENDOR: {
        evt_blue_aci *blue = (evt_blue_aci *)e->data;
        if (blue->ecode == EVT_BLUE_GATT_ATTRIBUTE_MODIFIED) {
            on_attribute_modified((evt_gatt_attr_modified_IDB05A1 *)blue->data);
        }
        break;
    }

    case EVT_HARDWARE_ERROR:
        s_needReinit = true;                                /* BlueNRG crashed: restart it */
        break;

    default:
        break;
    }
}

/* ---------------- Public API ---------------- */
void BLE_Init(void)
{
    uint16_t gap_serv, dev_name, appearance;
    uint8_t addr[6];

    hci_init(hci_event_cb, NULL);
    hci_reset();
    HAL_Delay(100);

    /* hci_tl_lowlevel_init() sets EXTI9_5 to priority 0: put it below the tick (see F7 notes) */
    HAL_NVIC_SetPriority(EXTI9_5_IRQn, 6, 0);
    HAL_NVIC_EnableIRQ(EXTI9_5_IRQn);

    make_address(addr);
    tBleStatus a = aci_hal_write_config_data(CONFIG_DATA_PUBADDR_OFFSET, 6, addr);
    tBleStatus b = aci_gatt_init();
    tBleStatus c = aci_gap_init_IDB05A1(GAP_PERIPHERAL_ROLE_IDB05A1, 0, 12, &gap_serv, &dev_name, &appearance);
    tBleStatus d = aci_gatt_update_char_value(gap_serv, dev_name, 0, 11, (uint8_t *)"BikeTracker");
    App_Log("[BLE] addr %02X:%02X:%02X:%02X:%02X:%02X hal=%02X gatt=%02X gap=%02X name=%02X\r\n",
            addr[5], addr[4], addr[3], addr[2], addr[1], addr[0], a, b, c, d);

    /* 12 attributes: service 1 + live 3 + dist 3 + ctrl 2 + hist 3 */
    tBleStatus s0 = aci_gatt_add_serv(UUID_TYPE_128, SERV_UUID, PRIMARY_SERVICE, 12, &s_serv);
    tBleStatus s1 = aci_gatt_add_char(s_serv, UUID_TYPE_128, LIVE_UUID, 16,
                                      CHAR_PROP_NOTIFY | CHAR_PROP_READ, ATTR_PERMISSION_NONE,
                                      GATT_DONT_NOTIFY_EVENTS, 16, 0, &s_live);
    tBleStatus s2 = aci_gatt_add_char(s_serv, UUID_TYPE_128, DIST_UUID, 4,
                                      CHAR_PROP_NOTIFY | CHAR_PROP_READ, ATTR_PERMISSION_NONE,
                                      GATT_DONT_NOTIFY_EVENTS, 16, 0, &s_dist);
    tBleStatus s3 = aci_gatt_add_char(s_serv, UUID_TYPE_128, CTRL_UUID, 9,
                                      CHAR_PROP_WRITE | CHAR_PROP_WRITE_WITHOUT_RESP, ATTR_PERMISSION_NONE,
                                      GATT_NOTIFY_ATTRIBUTE_WRITE, 16, 1 /* variable length */, &s_ctrl);
    tBleStatus s4 = aci_gatt_add_char(s_serv, UUID_TYPE_128, HIST_UUID, HP_MAX_FRAME,
                                      CHAR_PROP_NOTIFY, ATTR_PERMISSION_NONE,
                                      GATT_DONT_NOTIFY_EVENTS, 16, 1 /* variable length */, &s_hist);
    App_Log("[BLE] service=%02X live=%02X dist=%02X ctrl=%02X hist=%02X\r\n", s0, s1, s2, s3, s4);

    s_connected = false;
    start_advertising();
}

void BLE_Process(void)
{
    hci_user_evt_proc();
    if (s_needReinit) {
        s_needReinit = false;
        App_Log("[BLE] hardware error -> restart BlueNRG\r\n");
        BLE_Init();
    }
}

bool BLE_IsConnected(void) { return s_connected; }

void BLE_SendRecord(const GpsRecord_t *r)
{
    (void)aci_gatt_update_char_value(s_serv, s_live, 0, 16, (uint8_t *)r);
}

void BLE_SendDistance(uint32_t meters)
{
    (void)aci_gatt_update_char_value(s_serv, s_dist, 0, 4, (uint8_t *)&meters);
}

uint8_t BLE_SendHistFrame(const uint8_t *frame, uint8_t len)
{
    return aci_gatt_update_char_value(s_serv, s_hist, 0, len, (uint8_t *)frame);
}

bool BLE_TakeCommand(HpCommand_t *cmd)
{
    if (!s_cmdPending) return false;
    *cmd = s_cmd;
    s_cmdPending = false;
    return true;
}
