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
| 2026-11-17 | Scan loop on board, first run | Every key read one column off: the column wires were on PC5–PC8. Moved to PC4–PC7 ❌→✅ |
| 2026-11-17 | Scan loop on board, after rewiring | `1` → r8 0, r3 `0xE` · `6` → 1, `0xB` · `8` → 2, `0xD` · `#` → 3, `0xB` · `D` → 3, `0x7` ✅ |
| 2026-11-17 | RAM clear (Memory window) | `PinBuffer` at `0x20000004`; its 4 bytes and `DigitCount` read `00` after the clear ✅ |
| 2026-11-17 | Column search on board, breakpoint at `ColumnFound` | r4 = column, r5 = r3 every time (table below) ✅ |
| 2026-11-17 | Hold `1` and `2` together (same row) | No match; returns to `CounterReset`, `ColumnFound` never reached ✅ |

**Column search results** (board, 2026-11-17):

| Key | r8 (row) | r3 / r5 | r4 (column) | Screenshot |
|---|---|---|---|---|
| `1` | 0 | `0xE` | 0 | [KeyFound_Holding1](KeyFound_Holding1.png) |
| `6` | 1 | `0xB` | 2 | [KeyFound_Holding6](KeyFound_Holding6.png) |
| `8` | 2 | `0xD` | 1 | [KeyFound_Holding8](KeyFound_Holding8.png) |
| `#` | 3 | `0xB` | 2 | [KeyFound_HoldingHash](KeyFound_HoldingHash.png) |
| `D` | 3 | `0x7` | 3 | [KeyFound_HoldingD](KeyFound_HoldingD.png) |

**Character lookup results** (board, 2026-11-17, breakpoint after `LDRB r9`):

| Key | r7 (key number) | r9 (ASCII) | Screenshot |
|---|---|---|---|
| `6` | 6 | `0x36` | [ColumnFound_Holding6](ColumnFound_Holding6.png) |
| `#` | 14 (`0xE`) | `0x23` | [ColumnFound_HoldingHash](ColumnFound_HoldingHash.png) |
| `D` | 15 (`0xF`) | `0x44` | [ColumnFound_HoldingD](ColumnFound_HoldingD.png) |

**Release wait and bounce delay** (board, 2026-11-17): breakpoint on `wait`. Holding `6` (also for
several seconds) never reaches it; releasing reaches it right away ✅

**PIN entry** (board, 2026-11-18). Memory window at `PinBuffer` (`0x20000004`), which shows
`PinBuffer[0..3]`, then `DigitCount`, `AttemptCount`, `LockState`:

| Step | Keys | Memory | Result | Screenshot |
|---|---|---|---|---|
| 0 | (startup) | `.. .. .. .. | .. | 00 | 00` | `AttemptCount`/`LockState` were `40 08` (garbage) before the clear was added ✅ | [0](PinEntry_0_AllRamCleared.png) |
| 1 | `1` | `31 00 00 00 | 01` | stored at position 0 ✅ | [1](PinEntry_1_Press1.png) |
| 2 | `2` | `31 32 00 00 | 02` | ✅ | [2](PinEntry_2_Press2.png) |
| 3 | `*` | `00 00 00 00 | 00` | buffer wiped, count reset ✅ | [3](PinEntry_3_StarClears.png) |
| 4 | `3` | `33 00 00 00 | 01` | starts again at position 0 ✅ | [4](PinEntry_4_Press3AfterClear.png) |
| 5 | `4` | `33 34 00 00 | 02` | ✅ | [5](PinEntry_5_Press4.png) |
| 6 | `5` | `33 34 35 00 | 03` | ✅ | [6](PinEntry_6_Press5.png) |
| 7 | `6` | `33 34 35 36 | 04` | stops at `PinReady` ✅ | [7](PinEntry_7_Press6_PinReady.png) |
| 8 | `A` | unchanged | ignored ✅ | [8](PinEntry_8_IgnoreA.png) |
| 9 | `#` | unchanged | ignored ✅ | [9](PinEntry_9_IgnoreHash.png) |

**Buffer overflow found and fixed** (board, 2026-11-18): before the 4-digit check, presses 5, 6, 7 …
wrote past `PinBuffer` into `DigitCount`, `AttemptCount`, `LockState` and beyond ❌. With
`CMP r12,#4` / `BEQ PinReady` the 4th digit stops entry and nothing past `PinBuffer` changes ✅

## Register map (2026-11-18)

| Reg | Role | Type | Notes |
|---|---|---|---|
| r0 | GPIOC base `0x40020800` | Reserved | Temporary RAM/RCC addresses during setup |
| r1 | `RowPatterns` address | Reserved | Holds 0 during the RAM clear |
| r2 | `DigitCount` address | Reserved | |
| r3 | Column bits from IDR | Scratch | Pattern the column search matches |
| r4 | Column search counter → column 0–3 | Working | |
| r5 | Current `RowPatterns` entry in the search | Scratch | |
| r6 | `PinBuffer` address | Reserved | |
| r7 | Scratch | Scratch | `0xFFFF` mask at setup, ODR/IDR copies, key number 0–15 |
| r8 | Row 0–3 | Working | Row-loop counter |
| r9 | Row pattern (scan) → ASCII character (after decode) | Working | Stored before rescanning |
| r10 | Delay counter | Scratch | 1000 (settle), 80,000 (bounce) |
| r11 | `KeyValues` address | Reserved | |
| r12 | `DigitCount` value / zero for clearing | Scratch | Reloaded from RAM on every use |
| r13–r15 | SP, LR, PC | Do not use | |

