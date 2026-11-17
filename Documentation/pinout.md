# VaultLink Pin Map

**Board:** STM32F401RE Nucleo-64 · **Last updated:** 2026-11-16
**Status key:** Planned · Wired · Tested

## GPIOA: status outputs and Wi-Fi

| Pin | Connected to | Mode | Peripheral | Status |
|---|---|---|---|---|
| PA0 | Buzzer + | Alternate function | TIM2 CH1 | Planned |
| PA1 | Red LED (330 Ω to GND) | Output | GPIO | Planned |
| PA4 | ESP-01 RST | Output | GPIO | Planned |
| PA6 | Servo signal | Alternate function | TIM3 CH1 | Planned |
| PA8 | Green LED (330 Ω to GND) | Output | GPIO | Planned |
| PA9 | ESP-01 RX | Alternate function | USART1 TX | Planned |
| PA10 | ESP-01 TX | Alternate function | USART1 RX | Planned |

**Reserved, do not use:** PA2/PA3 (USB serial to PC), PA5 (on-board LED), PA13/PA14 (SWD debugger).

## GPIOB: LCD and lid sensor

| Pin | Connected to | Mode | Status |
|---|---|---|---|
| PB0–PB7 | LCD D0–D7 | Output | Planned (decision #5, proposed) |
| PB8 | LCD RS | Output | Planned |
| PB9 | LCD RW | Output | Planned |
| PB10 | LCD E | Output | Planned |
| PB12 | Lid reed switch (other wire to GND) | Input, pull-up, EXTI12 | Planned |

## GPIOC: keypad

| Pin | Connected to | Mode | Status |
|---|---|---|---|
| PC0–PC3 | Keypad rows 1–4 | Output | Tested |
| PC4–PC7 | Keypad columns 1–4 | Input, pull-up | Tested |

**Keypad ribbon mapping** (verified with a multimeter, 2026-11-15; pin 1 is leftmost with keys facing you):

| Ribbon pin | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Wire | Row 1 | Row 2 | Row 3 | Row 4 | Col 1 | Col 2 | Col 3 | Col 4 |
| STM32 pin | PC0 | PC1 | PC2 | PC3 | PC4 | PC5 | PC6 | PC7 |

Continuity checks: key `1` connects pins 1–5, key `2` connects pins 1–6, key `4` connects pins 2–5.

## Test log

| Date | Test | Result |
|---|---|---|
| 2026-11-15 | GPIOC setup on board: MODER, PUPDR, IDR in System Viewer | MODER `0x00000055`, PUPDR `0x00005500`, IDR `0x0000FFF0` ✅ |
| 2026-11-15 | All rows LOW, hold keys (board) | `1` → IDR4 low; `2` and `5` → IDR5 low ✅ |
| 2026-11-16 | `RowPatterns` in memory | `0E 0D 0B 07` ✅ |
| 2026-11-16 | Scan loop, no key (simulator, IDR = `0xF0`) | Reaches `B CounterReset` with r8 = 4, never `KeyFound` ✅ |
| 2026-11-16 | Scan loop, column 3 low (simulator, IDR = `0xB0`) | Stops at `KeyFound`, r8 = 0, r3 = `0xB` ✅ |
| pending | Scan loop on board, hold `6` | Expect `KeyFound`, r8 = 1, r3 = `0xB` |
