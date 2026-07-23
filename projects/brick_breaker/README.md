## brick_breaker

**Difficulty:** Advanced

**Uses MCU:** No

**External Hardware:** 4x 8x8 WS2812B LED Matrix Panels (configured as 16x16), 3x Push Buttons, External 5V Power Supply (Recommended)

## Overview

This example implements a classic, Breakout arcade game directly on the Shrike board. The FPGA handles all game logic, collision detection, physics, and rendering for a 256-LED (16x16) matrix display. You will learn about hardware debouncing, coordinate mapping for LED matrices, state machines for game logic, and driving timing-critical WS2812B addressable LEDs without a microcontroller.

## Compatibility

| Board                | Firmware                | Status     |
| -------------------- | ----------------------- | ---------- |
| Shrike-Lite (RP2040) | Not Required            | ✅ Tested   |
| Shrike (RP2350)      | Not Required            | ⬜ Untested |
| Shrike-fi (ESP32-S3) | Not Required            | ⬜ Untested |

> FPGA bitstream is the same across all boards. The MCU is not used in this project.

## Hardware Setup

### LED Matrix & Power (Important)

The display is constructed using four 8x8 WS2812B LED panels wired in a continuous data chain to create a 16x16 grid. 

* **Power Requirements:** 256 LEDs displaying bright colors can draw much high currents. An external 5V power supply is highly recommended to power the LED panels directly.
* Ensure the **ground** of your external power supply is connected to the **ground** of the Shrike board.
* Connect the push buttons between the input pins and GND.

### Pin Connections

| Signal           | Physical Pin |
| ---------------- | ------------ |
| Reset            | PIN 1        |
| Shoot Button     | PIN 0        |
| Left Button      | PIN 2        |
| Right Button     | PIN 7        |
| LED Output (DO)  | PIN 8        | 


## Quick Start (Pre-Built Bitstream)

1. Wire up the LED panels.
2. Connect your three push buttons and the WS2812B Data In line to the pins specified above.
3. Generate and upload the FPGA bitstream.
4. The game will start immediately. Use the Left/Right buttons to position the paddle, and the Shoot button to launch the ball!

## Build From Source

### FPGA (Verilog)

1. Open the project in the Go Configure Software Hub.
2. Paste the provided Verilog code into `main.v`.
3. Configure the I/O Planner matching the physical pins above.
4. Generate the bitstream.

## How It Works

1. **Button Debouncing:**
   Mechanical switches "bounce" when pressed, creating noisy signals. The `debounce` module uses a synchronized counter to ensure the button state is stable for a set number of clock cycles before registering a press.

2. **Game Physics & Timers:**
   Instead of using processor loops, the FPGA uses clock dividers (`player_timer` and `ball_timer`) to step the game state at playable arcade speeds. The paddle updates at 50 Hz, and the ball updates at 15 Hz.

3. **Coordinate Mapping:**
   The WS2812B driver expects a single, linear address (0-255). The hardware calculates spatial 4-bit `X` and `Y` coordinates based on this linear address. This allows the game logic to think in a standard Cartesian grid (0-15) while outputting a continuous data stream.

4. **Collision Logic:**
  ollision detection for all 15 bricks is evaluated simultaneously on a single clock edge. The system checks if the ball's (X,Y) coordinates overlap with any active brick's bounding box and reverses the ball's Y-direction immediately.


## Expected Output

> media/1.jpg

## Notes
Do not power led panel directly from Shrike lite board.
