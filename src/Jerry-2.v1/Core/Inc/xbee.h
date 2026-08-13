/*
 * xbee.h
 *
 *  Created on: Apr 2, 2026
 *      Author: danielpk
 */
#ifndef INC_XBEE_H_
#define INC_XBEE_H_

#include "main.h"
#include <stdint.h>

void XBee_Init(UART_HandleTypeDef *huart);
void XBee_StartRecv(void);
void XBee_SendString(const char *s);

uint8_t XBee_GetCommand(void);
uint8_t XBee_CmdReceived(void);
void XBee_ClearCmd(void);

void XBee_RXCallBack(UART_HandleTypeDef *huart);

#endif /* INC_XBEE_H_ */
