# 🚀 Tom & Jerry: Vision & Wireless Tracking Chase System

## 📌 Overview
An interactive physical gaming system inspired by the classic cartoon *Tom and Jerry*, built as a capstone project for EECS 373 at the University of Michigan. The system pairs a human-controlled robot (Tom) hunting an autonomous robot (Jerry) using overhead computer vision tracking, an XBee star-network, and a custom FPGA-driven VGA state-machine puzzle.

## 🛠️ Hardware & Tech Stack
* **Microcontrollers & Processors:** STM32L4R5ZI (ARM Cortex-M4), Altera DE2 FPGA, Raspberry Pi 3B
* **Peripherals / Protocols:** XBee RF (UART Star Network), VGA, PS2 Controller, Pi Camera / PixyCam, PWM Motor Control, ESP
* **Software Languages:** Embedded C/C++, Verilog (FPGA Logic), Python (Pi Vision)
* **Tools Used:** STM32CubeIDE, Altera Quartus, Oscilloscope, Logic Analyzer, Serial Terminal

## ✨ Key Features
- **Concurrent Star Network Communication:** Implemented custom XBee packet routing between the central hub and two independent STM32 robots with noise filtering and channel switching[cite: 1].
- **Real-Time Vision & Position Tracking:** Overhead Pi Camera tracking converts real-world arena coordinates into live map rendering on a VGA display[cite: 1].
- **State-Driven Gameplay Logic:** Custom FPGA logic handles real-time timer countdowns, randomized button sequence generation, and win/loss condition tracking[cite: 1].
- **Autonomous Obstacle Avoidance:** Jerry robot uses autonomous wall-detection algorithms to evade capture dynamically[cite: 1].

# 🚀 Video Demo
> 🎥 **[Click here to watch the full Video Demo on Google Drive](https://drive.google.com/file/d/1flRvvR6P50a103a1VQYP5l4vg7z9wXiW/view?usp=share_link))**


> ### 👤 My Role: Firmware Lead for "Jerry" (Autonomous Robot)
While I contributed to system integration and testing across the entire project, **my primary focus was designing, programming, and physically assembling the autonomous Jerry Robot (`src/Jerry.v1`)**:

* **Autonomous Driving Logic:** Programmed the STM32L4 MCU in C/C++ to execute autonomous navigation routines.
* **Obstacle Avoidance:** Integrated wall-detection sensors and written dynamic evasion algorithms to escape the Tom robot in real-time.
* **Wireless State Handler:** Handled incoming XBee UART command packets to trigger Jerry's 15-second frozen state and speed reduction mechanics.
* **Hardware Assembly:** Configured Jerry robot, including the batteries, motors, leds, microcrontroller on the chassis.
