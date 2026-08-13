/*
 * xbee.c
 *
 *  Created on: Apr 14, 2026
 *      Author: danielpk
 *      Edited By: liujosh
 */
#include "xbee.h"
#include "addresses.h"
#include <string.h>

#define sizeOfMsg 19

uint8_t camMsg[sizeOfMsg];
CamData camData; // (0, 0) top left. (303, 303) bottom right for vga arena
static uint8_t newCamData = 0;
static UART_HandleTypeDef *esp_uart;

void XBee_Init(UART_HandleTypeDef *huart) {
	camData.x1 = -1.15; // Tom
	camData.x2 = 1.15; // Jerry
	camData.y1 = -1.12;
	camData.y2 = 1.12;
	esp_uart = huart;
}

void XBee_StartRecv(void) {
	__HAL_UART_CLEAR_FLAG(esp_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF);
	HAL_UART_Receive_IT(esp_uart, camMsg, sizeOfMsg);
}

void XBee_SendString(const char *s) {
	HAL_UART_Transmit(esp_uart, (uint8_t *)s, strlen(s), HAL_MAX_DELAY);
	HAL_Delay(5);
}

CamData XBee_GetCamData() {
	return camData;
}

uint8_t XBee_CamReady() {
	return newCamData;
}

void XBee_ClearCamReady() {
	newCamData = 0;
}

void XBee_ErrCallBack(UART_HandleTypeDef *huart) {
	if (huart->Instance == esp_uart->Instance) {
		__HAL_UART_CLEAR_FLAG(esp_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF | UART_CLEAR_PEF);
		__HAL_UART_CLEAR_OREFLAG(esp_uart);
		HAL_UART_AbortReceive(esp_uart);
		HAL_UART_Receive_IT(esp_uart, camMsg, sizeOfMsg);
	}
}

void XBee_RXCallBack(UART_HandleTypeDef *huart) {
	uint8_t isHub = camMsg[0] == 'H' && camMsg[1] == 'u' && camMsg[2] == 'b';
	if (huart->Instance == esp_uart->Instance && isHub) {
		// Receives floats with x/y range [-1.22, 1.22]
		memcpy(&camData, &camMsg[3], sizeOfMsg-3); // Copy the 16 bytes to the respective floats
		newCamData = 1;
	}
	__HAL_UART_CLEAR_FLAG(esp_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF);
	HAL_UART_Receive_IT(esp_uart, camMsg, sizeOfMsg);
}




