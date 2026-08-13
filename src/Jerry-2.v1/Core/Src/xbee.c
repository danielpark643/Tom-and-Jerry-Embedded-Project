/*
 * xbee.c
 *
 *  Created on: Apr 2, 2026
 *      Author: danielpk
 */



#include "xbee.h"
#include <string.h>

static UART_HandleTypeDef *xbee_uart = NULL;
static uint8_t msg[5];
static uint8_t lastCommand;
static volatile uint8_t cmdReceived = 0;

void XBee_Init(UART_HandleTypeDef *huart) {
    xbee_uart = huart;
}

void XBee_StartRecv(void) {
    __HAL_UART_CLEAR_FLAG(xbee_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF);
    HAL_UART_Receive_IT(xbee_uart, msg, 5);
}

void XBee_SendString(const char *s) {
    HAL_UART_Transmit(xbee_uart, (uint8_t *)s, strlen(s), HAL_MAX_DELAY);
}

uint8_t XBee_GetCommand(void) {
    return lastCommand;
}

uint8_t XBee_CmdReceived(void) {
    return cmdReceived;
}

void XBee_ClearCmd(void) {
    cmdReceived = 0;
}

void XBee_RXCallBack(UART_HandleTypeDef *huart) {
    uint8_t isJer = (msg[0] == 'J' && msg[1] == 'e' && msg[2] == 'r');

    if (huart == xbee_uart && isJer) {
        lastCommand = msg[4];
        cmdReceived = 1;
    }

    __HAL_UART_CLEAR_FLAG(xbee_uart, UART_CLEAR_OREF | UART_CLEAR_NEF | UART_CLEAR_FEF);
    HAL_UART_Receive_IT(xbee_uart, msg, 5);
}
