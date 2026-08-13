/*
 * lidar.c
 *
 *  Created on: Mar 19, 2026
 *      Author: anton
 */


#include "lidar.h"
#include <stdio.h> // For printf

/* Private Variables (Hidden from main.c using the 'static' keyword) */
static VL53L0X_Dev_t Lidar;
static VL53L0X_Dev_t *pLidar = &Lidar;
static VL53L0X_RangingMeasurementData_t RangingData;
static volatile int NewDataReady = 0;
static uint16_t latest_distance_mm = 0xFFFF;

void Lidar_Init(I2C_HandleTypeDef *hi2c)
{
    uint32_t refSpadCount;
    uint8_t isApertureSpads;
    uint8_t VhvSettings;
    uint8_t PhaseCal;

    // 1. Basic Structure Setup
    pLidar->I2cHandle = hi2c;
    pLidar->I2cDevAddr = 0x52; // 8-bit address
    Lidar.Present = 1;

    // 2. Basic Initialization
    if (VL53L0X_DataInit(pLidar) != VL53L0X_ERROR_NONE) {
        printf("Lidar DataInit Failed!\r\n");
        return;
    }
    if (VL53L0X_StaticInit(pLidar) != VL53L0X_ERROR_NONE) {
        printf("Lidar StaticInit Failed!\r\n");
        return;
    }

    // 3. Hardware Calibration
    VL53L0X_PerformRefSpadManagement(pLidar, &refSpadCount, &isApertureSpads);
    VL53L0X_PerformRefCalibration(pLidar, &VhvSettings, &PhaseCal);

    // 4. High Accuracy Settings (Fixes Error 4)
    VL53L0X_SetMeasurementTimingBudgetMicroSeconds(pLidar, 200000);
    VL53L0X_SetLimitCheckValue(pLidar, VL53L0X_CHECKENABLE_SIGNAL_RATE_FINAL_RANGE, (FixPoint1616_t)(0.1 * 65536));

    // 5. Interrupt Configuration
    VL53L0X_SetGpioConfig(pLidar, 0,
            VL53L0X_DEVICEMODE_CONTINUOUS_RANGING,
            VL53L0X_GPIOFUNCTIONALITY_NEW_MEASURE_READY,
            VL53L0X_INTERRUPTPOLARITY_LOW);

    // 6. Start the Engine
    VL53L0X_SetDeviceMode(pLidar, VL53L0X_DEVICEMODE_CONTINUOUS_RANGING);
    VL53L0X_StartMeasurement(pLidar);

    // 7. Force clear the first interrupt to arm the system
    VL53L0X_ClearInterruptMask(pLidar, 0);
    NewDataReady = 0;

    printf("Lidar Initialized Successfully!\r\n");
}

/* This function acts as a bridge for the hardware interrupt */
void Lidar_SetDataReady(void)
{
    NewDataReady = 1;
}

/* This function handles the data retrieval and printing */
void Lidar_Process(void)
{
    if (NewDataReady) {
        NewDataReady = 0; // Clear software flag

        // Get the actual distance
        VL53L0X_GetRangingMeasurementData(pLidar, &RangingData);

        // Clear the hardware interrupt so the next pulse can happen
        VL53L0X_ClearInterruptMask(pLidar, 0);

        // Process Data
        if (RangingData.RangeStatus == 0) {
            latest_distance_mm = RangingData.RangeMilliMeter;
//        	printf("Lidar: %u mm\r\n", latest_distance_mm);

            // Example: if (RangingData.RangeMilliMeter < 200) Motor_Stop();
        } else {
            printf("Lidar Error Status: %d\r\n", RangingData.RangeStatus);
        }
    }
}

uint16_t Lidar_GetDistanceMM(void) {
	return latest_distance_mm;
}
