
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "xbee.h"
#include "controller.h"
#include <string.h>

#define NUM_ARROWS 10
#define SIZE_BUF 10

static UART_HandleTypeDef *vga_uart;

uint8_t arrows[NUM_ARROWS]; // 0 == right, 1 == up, 2 == left, 3 == down
volatile uint8_t arrows_ready = 1;

uint8_t Vga_ArrowsReady() {
	return arrows_ready;
}

void Vga_GetArrows(uint8_t* arrowBuf) {
	memcpy(arrowBuf, arrows, NUM_ARROWS);
}

void Vga_Init(UART_HandleTypeDef *huart) {
	vga_uart = huart;
}

void Vga_StartRecv(void) {
	__HAL_UART_CLEAR_FLAG(vga_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF);
	HAL_UART_Receive_IT(vga_uart, arrows, NUM_ARROWS);
}

void Vga_SendData(CamData camData) {
	  uint8_t sendBuf[SIZE_BUF]; // FF followed by EE is header for coordinates
	  sendBuf[0] = 0xFF;
	  sendBuf[1] = 0xEE;

	  int16_t x1 = GetPixelCords(camData.x1);
	  int16_t x2 = GetPixelCords(camData.x2);
	  int16_t y1 = GetPixelCords(camData.y1);
	  int16_t y2 = GetPixelCords(camData.y2);

	  // Pack Big-Endian: [HighByte, LowByte]
	  sendBuf[2] = (x1 >> 8) & 0xFF;
	  sendBuf[3] = x1 & 0xFF;
	  sendBuf[4] = (y1 >> 8) & 0xFF;
	  sendBuf[5] = y1 & 0xFF;
	  sendBuf[6] = (x2 >> 8) & 0xFF;
	  sendBuf[7] = x2 & 0xFF;
	  sendBuf[8] = (y2 >> 8) & 0xFF;
	  sendBuf[9] = y2 & 0xFF;

	  HAL_UART_Transmit(vga_uart, sendBuf, SIZE_BUF, 100);
}

void Vga_Start() {
	uint8_t sendBuf[2] = {0xFF, 0xAA}; // FF > AA means start
	HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_RESET);
	HAL_UART_Transmit(vga_uart, sendBuf, 2, 100);
}

void Vga_Stop() {
	uint8_t sendBuf[2] = {0xFF, 0xBB}; // FF > BB means stop
	HAL_UART_Transmit(vga_uart, sendBuf, 2, 100);
}

void Vga_Win() {
	uint8_t sendBuf[2] = {0xFF, 0xCC}; // FF > CC means Win
	HAL_UART_Transmit(vga_uart, sendBuf, 2, 100);
}

void Vga_Reset_Seq() {
	uint8_t sendBuf[2] = {0xFF, 0xDD}; // FF > DD means reset sequence
	HAL_UART_Transmit(vga_uart, sendBuf, 2, 100);
}

void Vga_RXCallBack(UART_HandleTypeDef *huart) {
	if (huart->Instance == vga_uart->Instance) {
		arrows_ready = 1;
	}
	__HAL_UART_CLEAR_FLAG(vga_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF);
	HAL_UART_Receive_IT(vga_uart, arrows, NUM_ARROWS);
}
