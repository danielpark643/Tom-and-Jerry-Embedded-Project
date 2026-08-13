/*
    ***** NOTE *****
    Edited by Josh Liu for USBC main connection
    No debug or other prints available, serial0 rerouted to serial and all serial.printf commented out

    ****************

    Wireless UART Bridge via ESP-NOW
    James Carl - 2026

    This sketch allows you to easily turn a wired uart connection into a wireless one.
    It uses Espressif's ESP-NOW and work with most ESP32s. Tested on the ESP32-C6 Xiao board.

    Once flashed, there is a CLI available via the USB com port that is used to configure the device.
    CLI is built using Stefan Kremser's SimpleCLI (github.com/spacehuhn/SimpleCLI).
*/

#include "ESP32_NOW.h"

#include "esp_wifi.h"
#include "WiFi.h"
#include <Preferences.h>
#include <SimpleCLI.h>

#define version 1.01

#define LED_PIN 15

#define RING_BUF_SIZE 64

hw_timer_t *LED_timer = NULL;
bool led_on = false;

volatile bool espnow_send_ready = true;

// Create CLI Object
SimpleCLI cli;

// Commands
Command cmdStatus;
Command cmdWifiChannel;
Command cmdSubChannel;
Command cmdUartBaud;
Command cmdSetPeer;
Command cmdDebugBaud;
Command cmdReset;
Command cmdHelp;

struct RX_Buf_Packet {
  byte buffer[1469];
  uint length;
};

//ESP-NOW rx/tx buffers
RX_Buf_Packet rx_ring_buffer[RING_BUF_SIZE];
volatile byte head = 0;
volatile byte tail = 0;
byte wifi_tx_buffer[1470];

//mux for buffer writes and reads
portMUX_TYPE mux = portMUX_INITIALIZER_UNLOCKED;

//NV stored values
uint debug_baud;
uint uart_baud;
uint wifi_channel;
uint8_t sub_channel;

//Broadcast address (default send to all)
uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

//Non-volitile Object
Preferences nvmem;

void OnDataRecv(const esp_now_recv_info *recv_info, const uint8_t *data, int len){
  if(data[0] != sub_channel) return;
  portENTER_CRITICAL(&mux);
  if(((head+1)%RING_BUF_SIZE) == tail){
    portEXIT_CRITICAL(&mux);
    //serial.println("ESPNow packet received but UART busy. Packet dropped(increase ring buffer size).");
    return;
  }
  memcpy(rx_ring_buffer[head].buffer, data+1, len-1);
  rx_ring_buffer[head].length = len-1;
  head = (head + 1) % RING_BUF_SIZE;
  portEXIT_CRITICAL(&mux);
}

void OnDataSent(const wifi_tx_info_t *tx_info, esp_now_send_status_t status) {
    espnow_send_ready = true;
}

//timer to keep LED on for at least 50ms
void IRAM_ATTR ledTimer() {
  digitalWrite(LED_PIN, 1); //LED off
  timerStop(LED_timer);
}

//CLI Callbacks:
void sendCallback(cmd* c) {
    Command cmd(c);
    String data = cmd.getArg(0).getValue();
    
    // We need 19 bytes for the STM32 to trigger its interrupt
    uint8_t rawBuffer[19];
    int byteCount = 0;

    // Remove any spaces the user might have accidentally typed
    data.replace(" ", "");

    // Convert hex string (e.g., "487562") to raw bytes
    for (int i = 0; i < data.length() && byteCount < 19; i += 2) {
        String hexPair = data.substring(i, i + 2);
        rawBuffer[byteCount++] = (uint8_t) strtol(hexPair.c_str(), NULL, 16);
    }

    // Send the raw bytes over the air via ESP-NOW
    wifi_tx_buffer[0] = sub_channel; // Set sub-channel header
    memcpy(&wifi_tx_buffer[1], rawBuffer, byteCount);
    
    esp_now_send(broadcastAddress, wifi_tx_buffer, byteCount + 1);

    //serial.printf("Sent %d binary bytes wirelessly.\n", byteCount);
}

void helpCallback(cmd* c) {
  //serial.println("Instructions at github.com/EECS373/wireless-uart");
  //serial.println("Commands:");
  //serial.println();
  //serial.println(cli.toString());
}

//stat
void statusCallback(cmd* c) {
  int temp = 0;
  //serial.println("Status:");
  //serial.printf("  Version: %.2f\r\n", version);
  //serial.printf("  Wifi Channel: %d\r\n", wifi_channel);
  //serial.printf("  Sub-channel: %d\r\n", sub_channel);
  //serial.printf("  MAC Address: %s\r\n", WiFi.macAddress().c_str());
  //serial.printf("  Peer: %02X:%02X:%02X:%02X:%02X:%02X (FF:FF:FF:FF:FF:FF = broadcast mode)\r\n",
    // broadcastAddress[0], broadcastAddress[1], broadcastAddress[2],
    // broadcastAddress[3], broadcastAddress[4], broadcastAddress[5]);
  //serial.printf("  UART Baud Rate: %d\r\n", uart_baud);
  //serial.printf("  Terminal/USB Baud Rate: %d\r\n", debug_baud);
}

void wifichannelCallback(cmd* c) {
  Command cmd(c);
  int channel = cmd.getArg(0).getValue().toInt();
  if(channel < 1 || channel > 11)
    int temp = 0;
    //serial.println("Invalid channel, must be a number from 1 to 11");
  else{
    nvmem.begin("parameters", false);
    nvmem.putUInt("wifichannel", channel);
    nvmem.end();
    wifi_channel = channel;
    esp_wifi_set_channel(wifi_channel, WIFI_SECOND_CHAN_NONE);
    esp_wifi_scan_stop();
    esp_now_peer_info_t peerInfo = {};
    memcpy(peerInfo.peer_addr, broadcastAddress, 6);
    peerInfo.channel = wifi_channel;
    peerInfo.encrypt = false;
    // if (esp_now_mod_peer(&peerInfo) != ESP_OK)
    //   //serial.println("Failed to modify peer");
    // else
      //serial.printf("Wi-Fi channel set to %d\r\n", wifi_channel);
  }
}

void subchannelCallback(cmd* c) {
  Command cmd(c);
  int channel = cmd.getArg(0).getValue().toInt();
  if(channel < 0 || channel > 255)
    int temp = 0;
    //serial.println("Invalid channel, must be a number from 0 to 255");
  else{
    nvmem.begin("parameters", false);
    nvmem.putUChar("subchannel", channel);
    nvmem.end();
    sub_channel = channel;
    //serial.printf("Sub-channel set to %d\r\n", sub_channel);
  }
}

void uartCallback(cmd* c) {
  Command cmd(c);
  int baud = cmd.getArg(0).getValue().toInt();
  if(baud < 1 || baud > 5000000)
    int temp = 0;
    //serial.println("Invalid baudrate, must be a number from 1 to 5000000");
  else{
    nvmem.begin("parameters", false);
    nvmem.putUInt("uartbaud", baud);
    nvmem.end();

    uart_baud = baud;
    Serial.begin(uart_baud);
    //serial.printf("UART baud set to %d\r\n", baud);
  }
}

void debugCallback(cmd* c) {
  Command cmd(c);
  int baud = cmd.getArg(0).getValue().toInt();
  if(baud < 1 || baud > 5000000)
    int temp = 0;
    //serial.println("Invalid baudrate, must be a number from 1 to 5000000");
  else{
    nvmem.begin("parameters", false);
    nvmem.putUInt("debugbaud", baud);
    nvmem.end();

    debug_baud = baud;
    //serial.begin(debug_baud);
    //serial.printf("Terminal/USB baud set to %d\r\n", baud);
  }
}

//peer
void setPeerCallback(cmd* c){
  Command cmd(c);
  String macStr = cmd.getArg(0).getValue();
  uint8_t mac[6];
  if(sscanf(macStr.c_str(), "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
            &mac[0],&mac[1],&mac[2],&mac[3],&mac[4],&mac[5]) != 6){
      //serial.println("Invalid MAC. Format: 12:34:56:78:9A:BC");
      return;
  }
  // Remove the OLD peer first
  esp_now_del_peer(broadcastAddress);

  memcpy(broadcastAddress, mac, 6);
  nvmem.begin("parameters", false);
  nvmem.putBytes("peer", broadcastAddress, 6);
  nvmem.end();

  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, mac, 6);
  peerInfo.channel = wifi_channel;
  peerInfo.encrypt = false;
  if(esp_now_add_peer(&peerInfo) == ESP_OK)
    int temp = 0;
      //serial.printf("Peer set to %s\r\n", macStr.c_str());
  else
    int temp = 0;
      //serial.println("Failed to modify peer");

}

//reset
void resetCallback(cmd* c) {
  memset(broadcastAddress, 0xFF, 6);
  nvmem.begin("parameters", false);
  nvmem.putUInt("wifichannel", 1);
  nvmem.putUInt("debugbaud", 115200);
  nvmem.putUInt("uartbaud", 115200);
  nvmem.putUChar("subchannel", 0);
  nvmem.putBytes("peer", broadcastAddress, 6);
  nvmem.end();
  wifi_channel = 1;
  uart_baud = 115200;
  debug_baud = 115200;
  sub_channel = 0;

  // Remove the OLD peer first
  esp_now_del_peer(broadcastAddress);

  esp_wifi_set_channel(wifi_channel, WIFI_SECOND_CHAN_NONE);
  esp_wifi_scan_stop();
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, broadcastAddress, 6);
  peerInfo.channel = wifi_channel;
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
      int temp = 0;
    //serial.println("Failed to modify peer");
  }
  Serial.begin(uart_baud);
  //serial.begin(debug_baud);
  //serial.println("Reset to defaults");
}

// Callback in case of an error
void errorCallback(cmd_error* e) {
    CommandError cmdError(e); // Create wrapper object

    //serial.print("ERROR: ");
    //serial.println(cmdError.toString());

    if (cmdError.hasCommand()) {
        //serial.print("Did you mean \"");
        //serial.print(cmdError.getCommand().toString());
        //serial.println("\"?");
    }
}

void setup() {
  //Initialize LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, 0); //indicate that in setup
  
  // Open namespace "parameters" in read-write mode (false)
  nvmem.begin("parameters", false);

  //start timer
  LED_timer = timerBegin(1000000); // 1 MHz

  //trigger interrupt with timer every 100ms
  timerAttachInterrupt(LED_timer, &ledTimer);

  // Get stored values
  debug_baud = nvmem.getUInt("debugbaud", 115200);
  uart_baud = nvmem.getUInt("uartbaud", 115200);
  wifi_channel = nvmem.getUInt("wifichannel", 1);
  sub_channel = nvmem.getUChar("subchannel", 0);
  if(nvmem.getBytesLength("peer") == 6){
    nvmem.getBytes("peer", broadcastAddress, 6);
  }

  nvmem.end();

  //Increase UART buffer size
  Serial.setTxBufferSize(16384);
  Serial.setRxBufferSize(16384);

  //Start USB Serial for debug messages
  //serial.begin(debug_baud);

  //Start UART Serial
  Serial.setTimeout(3); //set timeout to 3 milliseconds, will transmit after timeout
  Serial.begin(uart_baud);

  // Set device as a Wi-Fi Station
  WiFi.mode(WIFI_STA);
  esp_wifi_set_channel(wifi_channel, WIFI_SECOND_CHAN_NONE);
  esp_wifi_scan_stop();

  // Init ESP-NOW
  if (esp_now_init() != ESP_OK) {
    //serial.println("Error initializing ESP-NOW");
    return;
  }
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, broadcastAddress, 6);
  peerInfo.channel = wifi_channel;
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    // Serial.println("Failed to modify peer");
  }

  //CLI command

  Command cmdSend = cli.addSingleArgCmd("send", sendCallback);
  cmdSend.setDescription("  Send string via UART");

  cmdStatus = cli.addCommand("stat", statusCallback);
  cmdStatus.setDescription("  See configured channel and baud rates");

  cmdWifiChannel = cli.addSingleArgCmd("channel", wifichannelCallback);
  cmdWifiChannel.setDescription("  Set wifi channel (1-11)");

  cmdSubChannel = cli.addSingleArgCmd("subchannel", subchannelCallback);
  cmdSubChannel.setDescription("  Set sub-channel (0-255)");

  cmdUartBaud = cli.addSingleArgCmd("uartbaud", uartCallback);
  cmdUartBaud.setDescription("  Configure uart port baud rate");

  cmdDebugBaud = cli.addSingleArgCmd("debugbaud", debugCallback);
  cmdDebugBaud.setDescription("  Configure baud rate for this terminal(USB)");

  cmdSetPeer = cli.addSingleArgCmd("peer", setPeerCallback);
  cmdSetPeer.setDescription("  Set the receiving peer (limit 1). Format: 01:23:45:67:89:AB");

  cmdReset = cli.addCommand("reset", resetCallback);
  cmdReset.setDescription("  Reset all configurations to default.\r\n  WiFi Channel to 1.\r\n  UART and USB baud rate to 115200.\r\n");

  cmdHelp = cli.addCommand("help", helpCallback);
  cmdHelp.setDescription("  Help:\n\r  List of commands:\n\r");

  cli.setOnError(errorCallback);

  //ESPNow receive callback
  esp_now_register_recv_cb(OnDataRecv);

  //ESPNow sent callback
  esp_now_register_send_cb(OnDataSent);

  digitalWrite(LED_PIN, 1); //setup done, turn off LED
}

void loop() {
  if(Serial.available() && espnow_send_ready){
    uint bytes_received = Serial.readBytes(&wifi_tx_buffer[1], 1469);
    wifi_tx_buffer[0] = sub_channel;
    espnow_send_ready = false;
    esp_err_t result = esp_now_send(broadcastAddress, wifi_tx_buffer, bytes_received+1);
      if (result == ESP_OK){
        //serial.printf("Sent %d byte(s)\r\n", bytes_received); //uncomment for debug
        for(int i = 1; i <= bytes_received; i++) {
            //serial.printf("%02X ", wifi_tx_buffer[i]);
        }
      }
      else{
        //serial.println("Error sending via ESPNow");
        espnow_send_ready = true;
      }
  }

  while(true) {
    byte temp_buf[1469];
    uint temp_length;

    portENTER_CRITICAL(&mux);
    if(tail == head) {
      portEXIT_CRITICAL(&mux);
      break;
    }
    memcpy(temp_buf, rx_ring_buffer[tail].buffer, rx_ring_buffer[tail].length);
    temp_length = rx_ring_buffer[tail].length;
    tail = (tail + 1) % RING_BUF_SIZE;
    portEXIT_CRITICAL(&mux);

    digitalWrite(LED_PIN, 0); //LED on

    // Debug
    //serial.printf("Writing %d byte(s) to UART: ", temp_length);
    for(int i = 0; i < temp_length; i++) {
        //serial.printf("%02X ", temp_buf[i]);
    }
    //serial.println();

    Serial.write(temp_buf, temp_length);
//    //serial.printf("Received %d byte(s)\r\n", rx_ring_buffer[current_tail].length); //uncomment for debug

    timerRestart(LED_timer); //reset timer to 0
    timerAlarm(LED_timer, 50000, false, 0); // trigger an interrupt at 50ms
    timerStart(LED_timer); // start timer
  }
  // if (serial.available()*/) {
  //       String input = //serial.readStringUntil('\n');
  //       if (input.length() > 0) {
  //           //serial.print("# ");
  //           //serial.println(input);
  //           cli.parse(input);
  //       }
  //   }
}