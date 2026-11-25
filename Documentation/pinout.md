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

LCD wired 2026-11-22: D0–D7 = PB0–PB7, RS = PB8, E = PB9, RW = GND (PB10 not used).

| Pin | Connected to | Mode | Status |
|---|---|---|---|
| PB0–PB7 | LCD D0–D7 | Output | Tested (#44) |
| PB8 | LCD RS | Output | Tested (#44) |
| PB9 | LCD E | Output | Tested (#44) |
| — | LCD RW tied to GND (write only) | — | Tested (#44) |
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

**User table and PIN check** (board, 2026-11-19). Memory window from `PinBuffer` (`0x20000004`):
`PinBuffer[0..3]`, `DigitCount`, `AttemptCount`, `LockState`, `ActiveRole`.

| Test | Result | Screenshot |
|---|---|---|
| Copy defaults to RAM | `UserPins` = `"6827" "1234" "5678" 00000000`, `UserRoles` = `01 00 00 00` then zeros ✅ | [UserTable_CopiedToRAM](UserTable_CopiedToRAM.png) |
| User PIN `1234` | stops at `Match`; `LockState` = 01, `ActiveRole` = 00 ✅ | [PinCheck_User](PinCheck_User.png) |
| Owner PIN `6827` | `LockState` = 01, `ActiveRole` = 01 (survives the `LockState` write) ✅ | [PinCheck_Owner](PinCheck_Owner.png) |
| Wrong PIN `9999` | r3 = `0x39393939`, r12 = 4 (all slots tried, empty slot never matches), stops at `NoMatch`, nothing unlocked ✅ | [PinCheck_Wrong](PinCheck_Wrong.png) |
| 3 wrong, owner, 1 wrong (video) | `AttemptCount` 01 → 02 → 03 → 00 (reset on success) → 01 ✅ | [AttemptCount_Sequence](AttemptCount_Sequence.png) |

Known gap: after unlocking, the keypad still accepted PINs. Fixed 2026-11-20 (#39).

**Lock states** (board, 2026-11-20). Memory from `0x20000004`; `LockState` is byte `…0A`,
`ActiveRole` byte `…0B`.

| Test | Result | Evidence |
|---|---|---|
| User `1234`, then keys while unlocked, then `#` | unlocks (01/00); `DigitCount` stays 00 while unlocked; `#` → `LockState` 00 ✅ | video |
| Owner `6827`, then `B` (breakpoint on `OwnerMenu`) | halts at `0x08000376` = `OwnerMenu`, r9 = `0x42`, r3 = 1 ✅ | [OwnerB_StopsAtOwnerMenu](OwnerB_StopsAtOwnerMenu.png) |
| User `1234`, then `B`, then `#` | never halts at `OwnerMenu`; `#` still locks, so the CPU kept scanning ✅ | [LockStates_Sequence](LockStates_Sequence.png) |
| `A` key (breakpoint on `Filter`) | never reaches `Filter`; `B` does, with row 1, col 3, key 7, `0x42`. Dead `A` contact ❌ → owner key moved to `B` (#40) | [KeyA_Dead_KeyB_ReachesFilter](KeyA_Dead_KeyB_ReachesFilter.png) |

**Lockout** (board, 2026-11-20). Memory from `0x20000004`: `PinBuffer`, `DigitCount`,
`AttemptCount`, `LockState`, `ActiveRole`.

| Test | Result | Evidence |
|---|---|---|
| User unlock, `#`, 3 wrong PINs, user PIN in lockout, owner PIN in lockout | `AttemptCount` 01 → 02 → 03 with `LockState` 02; user refused (still 02, not counted); owner → `LockState` 01, `AttemptCount` 00 ✅ | [Lockout_StateSequence](Lockout_StateSequence.png) |
| Delay with 160,000,000 counts | waits measured at **40 s** (0:15.5 → 0:55.5, 1:03.5 → 1:43.5, 1:48 → 2:28); owner opens with no wait ✅ → recalibrated (#43) | [Lockout_40s_BeforeCalibration](Lockout_40s_BeforeCalibration.png) |
| Delay with 120,000,000 counts, wipe before wait | buffer reads `00 00 00 00` immediately after the 3rd wrong PIN; keypad responds again after about 30 s; owner unlocks ✅ | [Lockout_30s_Calibrated](Lockout_30s_Calibrated.png) |

**LCD** (board, 2026-11-22)

| Test | Result | Evidence |
|---|---|---|
| Power, backlight, contrast (no code) | backlight on, character cells visible after adjusting the pot ✅ | |
| GPIOB setup | MODER = `0x00055555`; keypad still works ✅ | |
| "ENTER PIN:" | "ENTER PI" correct; `N` faint, `:` missing → columns 9–11 dead (#48) | [LCD_DeadColumns_EnterPin](LCD_DeadColumns_EnterPin.jpg), [LCD_DeadColumns_FullContrast](LCD_DeadColumns_FullContrast.jpg) |
| `LCDString` with `"PIN:",0` | `PIN:` with the cursor in column 5 ✅ | [LCD_PinPrompt](LCD_PinPrompt.jpg) |
| Stars, `*` reset, wrong PIN, owner unlock, `#`, 3 wrong PINs | a `*` per digit; screen follows `LockState`: `LOCKED` / `OPEN` / `LOCKOUT` (shown at the start of the wait) ✅ | |
| Lockout cursor (LCDDisplayTest video, 52 s): 3 wrong PINs, wait 30 s, type, owner PIN, `#`, 3 wrong PINs | before the fix the cursor stayed after `LOCKOUT` on row 2; with `0x84` in `ScreenLockout` it sits after `PIN:` and the stars land on row 1 ✅. `LOCKOUT` stays after the 30 s (only the owner PIN ends it, #37) ✅; owner → `OPEN`, `#` → `LOCKED`, 3 more wrong PINs → `LOCKOUT` again (counter was reset) ✅ | [LCD_Screens_Lockout_Open_Locked](LCD_Screens_Lockout_Open_Locked.jpg) |

**Owner menu, slice 1** (board, 2026-11-25). Memory from `0x20000004`: `PinBuffer`, `DigitCount`,
`AttemptCount`, `LockState`, `ActiveRole`.

| Test | Result | Evidence |
|---|---|---|
| Owner PIN, then `B` | screen `C:+  D:-` / `B:Away`; memory `… 00 00 03 01` (`LockState` 3, `ActiveRole` 1) ✅ | [AdminMenu_Slice1_OpenAndExit](AdminMenu_Slice1_OpenAndExit.jpg) |
| User PIN, then `B` | stays `OPEN`; memory `… 00 00 01 00` (`LockState` 1, `ActiveRole` 0) ✅ | [AdminMenu_Slice1_OpenAndExit](AdminMenu_Slice1_OpenAndExit.jpg) |
| Digits and `*` in the menu | ignored: no stars, `PinBuffer` and `DigitCount` stay 0 (after adding `B CounterReset` to `AdminKeys`; before it, keys fell into `StoreDigit`) ✅ | |
| `#` in the menu | `LOCKED`, `LockState` 0 ✅ | |

**Owner menu, slice 2: away mode** (board, 2026-11-25). Same memory view.

| Test | Result | Evidence |
|---|---|---|
| Owner, `B` (menu), `B` | `… 00 03 02 01`: `AttemptCount` 3, `LockState` 2 ✅ | [AdminMenu_Slice2_AwayMode](AdminMenu_Slice2_AwayMode.png) |
| User PIN in away mode | refused, not counted, buffer wiped, about 30 s wait ✅ | |
| Owner PIN in away mode | `… 00 00 01 01`: unlocked, `AttemptCount` 0 ✅ | [AdminMenu_Slice2_AwayMode](AdminMenu_Slice2_AwayMode.png) |
| `#` from state 1 and from the menu | `LockState` 0 both times (`LockBox` now asks `SecureBox` first) ✅ | [AdminMenu_Slice2_AwayMode](AdminMenu_Slice2_AwayMode.png) |

**Owner menu, slice 3: add user** (board, 2026-11-25). Memory from `0x20000004`; `UserPins` slot 3 at
`0x20000018`, its role at `0x20000028`.

| Test | Result | Evidence |
|---|---|---|
| `C` with room | add screen `PIN:` / `ADD USER`, `LockState` 4 ✅ | |
| `C` with a full table (temporary 4th default PIN) | `FULL` for about 1 s, stays in the menu (`LockState` 3) ✅ | |
| Digits, `*`, letters, `#` on the add screen | stars appear; `*` clears; `B`/`C` ignored; `#` locks ✅ | |
| 4 digits on the add screen (before `SaveUser` was written) | back to the menu, `AttemptCount` 0: never reached the PIN check ✅ | |
| Add `4321` | slot 3 = `34 33 32 31`, role 0, back to the menu ✅ | [AdminMenu_Slice3_AddUser](AdminMenu_Slice3_AddUser.png) |
| Lock, then `4321` | `OPEN` with `ActiveRole` 0; `B` does nothing ✅ | [AdminMenu_Slice3_AddUser](AdminMenu_Slice3_AddUser.png) |
| Add `1234` (already a user) | `EXISTS`, table unchanged ✅ (seen on the LCD; photo to add) | |
| `C` with slot 3 now used | `FULL` ✅ (seen on the LCD; photo to add) | |
| Owner after all of the above | slot 0 still `36 38 32 37`, role 1; owner opens the menu ✅ | [AdminMenu_Slice3_AddUser](AdminMenu_Slice3_AddUser.png) |

## Register map (2026-11-22)

Also as a PDF: [VaultLink_Register_Map.pdf](VaultLink_Register_Map.pdf).

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
| r10 | Delay counter | Scratch | 1000 (settle, 250 µs), 80,000 (bounce, 20 ms), 120,000,000 (lockout, 30 s) |
| r11 | `KeyValues` address | Reserved | |
| r12 | `DigitCount` value / zero for clearing | Scratch | Reloaded from RAM on every use |
| r13–r15 | SP, LR, PC | Do not use | |

**LCD routines** preserve every register they change. Argument: byte in **r3**
(`LCDCommand`, `LCDChar`); string address in **r7** (`LCDString`). Inside: r5 = GPIOB base,
r7 = RS/E value, r10 = `delay` counter.

**PIN check (`PinReady` → `Match` / `NoMatch`), reloaded on every entry:** r3 typed PIN, then the
matched role · r4 stored PIN · r7 `UserPins` address, then RAM variable addresses · r10 `UserRoles`
address · r12 slot counter, then values to store.

**Copy loop (setup):** r3 counter · r4 `DefaultPins` · r8 `DefaultRoles` · r9 `UserPins` ·
r10 `UserRoles` · r5 word being copied.

**RAM:** `PinBuffer` `…04–07`, `DigitCount` `…08`, `AttemptCount` `…09`, `LockState` `…0A`,
`ActiveRole` `…0B`, `UserPins` `…0C–1B`, `UserRoles` `…1C–2B` (all `0x2000xxxx`; use the labels).

