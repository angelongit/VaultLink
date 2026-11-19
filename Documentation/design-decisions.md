# VaultLink Design Decisions

Each entry records one choice: the problem, the options, what we chose, why, and what it affects.
Newest entries are at the bottom. If a decision is reversed, add a new entry and mark the old
one **Superseded by #N**. Never delete an entry.

**Status values:** Accepted · Proposed (needs teammate sign-off) · Open (not decided yet)

| # | Decision | Status |
|---|---|---|
| 1 | Keypad on GPIOC (PC0–PC7), not GPIOA | Accepted |
| 2 | Buzzer moved from PB10 to PA0 | Accepted |
| 3 | 4×4 keypad instead of 3×4 | Accepted |
| 4 | 16×2 LCD for output, 4-digit 7-segment dropped | Accepted |
| 5 | LCD in 8-bit mode on GPIOB | Proposed |
| 6 | Active-low keypad scan with column pull-ups | Accepted |
| 7 | Read-modify-write for every peripheral register | Accepted |
| 8 | Row patterns stored in a lookup table | Accepted |
| 9 | `LDRB` (not `LDR`) to read the table | Accepted |
| 10 | Fixed register map for the scan loop | Accepted |
| 11 | Busy-wait settle delay of 1000 counts per row | Accepted |
| 12 | Normalize column bits with `AND` + `LSR #4` | Accepted |
| 13 | Compare columns against the constant `0xF` | Accepted |
| 14 | Branch away on key found; no-key path falls through | Accepted |
| 15 | `BLO` as the row-loop exit condition | Accepted |
| 16 | Single `CounterReset` entry point for each scan | Accepted |
| 17 | Test scan logic in the Keil simulator with mapped peripherals | Accepted |
| 18 | PIN entry: fixed 4 digits, auto-submit | Accepted |
| 19 | Attempt counter resets on a correct PIN | Accepted |
| 20 | Lockout exit condition | Resolved by #37 |
| 21 | Runtime variables in a `READWRITE` RAM area, cleared at startup | Accepted |
| 22 | PIN digits stored as ASCII; `*` clears entry | Accepted |
| 23 | Column decode by searching the `RowPatterns` table | Accepted |
| 24 | Multi-key presses rejected by the column search | Accepted |
| 25 | Key number = row × 4 + column, then a 16-byte ASCII lookup table | Accepted |
| 26 | Wait for key release, then a 15 ms bounce delay | Accepted |
| 27 | Accept digits only: `*` first, then a two-compare range check | Accepted |
| 28 | Stop entry at 4 digits (prevents a buffer overflow) | Accepted |
| 29 | `*` wipes `PinBuffer` as well as resetting `DigitCount` | Accepted |
| 30 | Clear every RAM variable at startup | Accepted |
| 31 | One job per reserved register (mask moved from r2 to r7) | Accepted |
| 32 | Owner and user roles (TA suggestion) | Accepted |
| 33 | User table: parallel PIN and role tables, defaults in flash, live copy in RAM | Accepted |
| 34 | Compare a whole PIN as one word; PIN word 0 marks an empty slot | Accepted |
| 35 | `ActiveRole` variable; `LockState` says whether it is meaningful | Accepted |
| 36 | Keypad behavior by state; lock with lid closed + `#`; auto re-lock | Accepted |
| 37 | Lockout: only the owner PIN clears it, with a delay per attempt | Accepted |
| 38 | Fail-secure latch; RTC timestamps are a stretch goal | Accepted |

---

## #1: Keypad on GPIOC instead of GPIOA

- **Date:** 2026-11-15 · **Status:** Accepted

**Context.** The original split put the keypad, status LEDs and buzzer all on GPIOA. Counting
GPIOA's pins showed it can't hold an 8-pin keypad.

**Options.** (1) Keypad on GPIOA. (2) Keypad on GPIOC, PC0–PC7.

**Decision.** Keypad rows on PC0–PC3, columns on PC4–PC7.

**Reasons.**
- Several GPIOA pins are already taken: PA2/PA3 (USB serial link to the PC), PA5 (on-board LED),
  PA13/PA14 (SWD debugger, reconfiguring them cuts off Keil), and PA4/PA6/PA9/PA10 (ESP-01 and
  servo). That leaves about 6 free pins; the keypad needs 8.
- Eight adjacent pins on one port make scanning simpler: one IDR read gives every column in a
  known bit position. *Port Programming* slide 46 lists PC0–PC12 as safe pins.

**Consequences.** GPIOA holds the LEDs, buzzer, servo and ESP-01. GPIOC holds the keypad.
ESP-01 pins are unchanged.

---

## #2: Buzzer moved from PB10 to PA0

- **Date:** 2026-11-15 · **Status:** Accepted

**Context.** We decided GPIOB should be used only for the LCD (and the lid switch).

**Decision.** Buzzer on PA0.

**Reasons.** PA0 connects to a timer channel (TIM2 CH1), so it can still produce tones with PWM.

**Consequences.** The buzzer code uses TIM2 **channel 1** registers instead of channel 3.

---

## #3: 4×4 keypad instead of 3×4

- **Date:** 2026-11-15 · **Status:** Accepted

**Reasons.** The design uses the A and D keys (admin menu, lock now), which only the 4×4 has.
Four rows and four columns split evenly across PC0–PC3 and PC4–PC7.

**Consequences.** The 3×4 keypad is kept as a spare.

---

## #4: 16×2 LCD for output; 4-digit 7-segment dropped

- **Date:** 2026-11-15 · **Status:** Accepted

**Reasons.** The bare 4-digit display needs about 12 more pins (no room left) and continuous
multiplexing. The final project uses the 16×2 LCD anyway, so effort spent there carries forward.

**Consequences.** During development, keys are verified in the Keil debugger first, then on the LCD.

---

## #5: LCD in 8-bit mode on GPIOB

- **Date:** 2026-11-15 · **Status:** Proposed (needs teammate sign-off)

**Context.** Lab 6 ran the LCD in 8-bit mode with data on PC0–PC7, which now belong to the keypad.

**Options.** (1) 8-bit mode moved to GPIOB. (2) 4-bit mode on GPIOB.

**Proposal.** Data D0–D7 on PB0–PB7, RS on PB8, RW on PB9, E on PB10. Lid switch stays on PB12.

**Reasons.** Our working Lab 6 code only needs its port address and bit positions changed, not
its logic. 4-bit mode saves pins but means rewriting how every byte is sent, and GPIOB has room.

---

## #6: Active-low keypad scan with column pull-ups

- **Date:** 2026-11-15 · **Status:** Accepted

**Context.** A keypad key doesn't connect to 3.3 V or GND. It connects a row wire to a column wire,
and we choose the voltage on the rows.

**Options.**
1. Active-low: columns pulled up; the row being scanned is driven LOW; a pressed key reads 0.
2. Active-high: columns pulled down; the row being scanned is driven HIGH; a pressed key reads 1.

**Decision.** Option 1. Columns PC4–PC7 have internal pull-ups (PUPDR = `01`). One row at a time is
driven LOW; the others are HIGH.

**Reasons.**
- Without a pull resistor, an unpressed column is floating and reads random values, which would
  cause phantom key presses. The pull-up gives every column a defined idle level of 1.
- Active-low is the common convention for matrix keypads.
- It allows the rows to be made open-drain later, so two keys pressed together can never short
  two outputs.

**Why one row at a time.** Tested on hardware with all rows LOW: key `1` cleared IDR4, and keys
`2` and `5` both cleared IDR5, so keys in the same column were indistinguishable. Driving one row
LOW at a time means a column can only read 0 if the pressed key is on that row. The row being
driven gives the key's row; the column that reads 0 gives its column.

---

## #7: Read-modify-write for every peripheral register

- **Date:** 2026-11-15 · **Status:** Accepted

**Context.** The first clock-enable attempt wrote `4` directly to RCC_AHB1ENR. That turns GPIOC on
but turns every other port's clock off.

**Decision.** Every register change is `LDR` (read) → `BIC` / `ORR` (modify) → `STR` (write).

**Reasons.**
- ARM is a load/store architecture: `BIC`, `ORR` and other data instructions only work on
  registers, so a value must be loaded, changed, and stored back.
- Reading first means every bit we don't own goes back unchanged. Only our own pins change.
- 2-bit fields (MODER, PUPDR) need `BIC` before `ORR`: ORing `01` into a field that holds `10`
  gives `11`, the wrong mode. Clearing the field first avoids that.
- Masks cover only our pins (`0x0000FFFF` for PC0–PC7), never the whole register, so PC8–PC15
  (including the PC13 user button) are untouched.

**Consequences.** `0x0000FFFF` doesn't fit as an instruction immediate, so it is loaded with
`LDR rX,=0x0000FFFF` and used through the register form of `BIC`.

---

## #8: Row patterns stored in a lookup table

- **Date:** 2026-11-15 · **Status:** Accepted

**Options.** (1) Lookup table of the four patterns. (2) Calculate each pattern by shifting a 1
into position and inverting it.

**Decision.** Lookup table `RowPatterns DCB 0xE, 0xD, 0xB, 0x7`, in its own read-only data area
after the code.

**Reasons.** Most readable, and easy to check in the debugger's Memory window.

**Consequences.** The row counter (0–3) is used directly as the table index. Row 1's pattern is
entry 0, so the counter starts at 0.

---

## #9: `LDRB` (not `LDR`) to read the table

- **Date:** 2026-11-16 · **Status:** Accepted

**Reasons.** Each table entry is one byte (`DCB`). Plain `LDR` loads a 4-byte word, so with the
table `0E 0D 0B 07` in memory (little-endian) it would load `0x070B0D0E`. The row write clears only
bits 0–3 before ORing the pattern in, so the extra bytes would switch on pins PC8 and above. The
keypad would still appear to work, which makes the bug easy to miss.

---

## #10: Register map for the scan loop

- **Date:** 2026-11-16 · **Status:** Accepted

| Purpose | Register | Changes inside the loop? |
|---|---|---|
| GPIOC base address | r0 | No |
| RowPatterns table address | r1 | No |
| Column bits (normalized) | r3 | Yes |
| Scratch for read-modify-write | r7 | Yes |
| Row counter (0–3) | r8 | Yes |
| Current row pattern | r9 | Yes |
| Settle-delay countdown | r10 | Yes |

**Reasons.** Each job gets its own register so nothing the loop still needs is overwritten.
The first attempt reused r0 (GPIOC base) for the table and r1 (scratch) as the counter, which
would have lost the GPIOC address and corrupted the counter on the first ODR read.

**Consequences.** When the scan becomes a subroutine, the r0–r3 / r4–r11 convention from the
*Subroutines* slides will apply (save r4–r11 with PUSH/POP).

---

## #11: Settle delay of 1000 counts per row

- **Date:** 2026-11-16 · **Status:** Accepted

**Context.** After the rows change, the keypad wires need a moment to reach their new levels.
Reading IDR immediately could show the previous row's result.

**Decision.** A `SUBS` / `BNE` countdown from 1000, labelled `KeypadSettle`.

**Reasons.**
- `SUBS` updates the Z flag; `BNE` reads it. Without the `S`, Z would never change inside the
  loop, so `BNE` would act on a stale flag: the loop would exit after one pass or never.
- Timing at 16 MHz: 1000 passes × ~3 cycles = 3000 cycles × 62.5 ns = **187.5 µs per row**,
  **0.75 ms per full scan**. The rows need only a few µs, so this is a generous margin, and a key
  press (~100 ms) is still scanned more than 100 times.

**Consequences.** Could be reduced to ~50–100 counts later for a faster scan.

---

## #12: Normalize column bits with `AND` + `LSR #4`

- **Date:** 2026-11-16 · **Status:** Accepted

**Decision.** Read IDR, `AND` with `0xF0` to keep only the columns (bits 4–7), then `LSR #4` to
move them to bits 0–3.

**Reasons.**
- `AND` keeps the bits in the mask. (`BIC` with `0xFFFFFF0F` gives the same result but describes
  what to remove rather than what to keep.)
- After the shift, "no key" is `0xF` and one pressed key is `0xE`, `0xD`, `0xB` or `0x7`, the same
  values as the row patterns. Small values (0–15) can index a lookup table directly when decoding
  the key. Unshifted they'd be `0xE0`, `0xD0` and so on.

---

## #13: Compare columns against the constant `0xF`

- **Date:** 2026-11-16 · **Status:** Accepted

**Context.** The first version compared the columns with the row pattern (`CMP r3, r9`).
Traced with row 1 and no key pressed: r9 = `1110`, r3 = `1111`, not equal, so the branch was taken
and a key was reported on every row with nothing pressed.

**Decision.** `CMP r3, #0xF`.

**Reasons.** r9 is the pattern being *driven* onto the rows, not what the columns read when idle.
With no key pressed, the pull-ups make the columns read `1111` on every row, so "no key" is the
same constant whichever row is being scanned.

---

## #14: Branch away on key found; no-key path falls through

- **Date:** 2026-11-16 · **Status:** Accepted

**Options.** (A) `BNE KeyFound`, with the next-row code directly underneath. (B) `BEQ` to a
no-key label, with the key-found code directly underneath.

**Decision.** Option A.

**Reasons.** "No key on this row" is the common case, so the normal loop reads straight down the
page. The rare case (key found) is the one that jumps away.

---

## #15: `BLO` as the row-loop exit condition

- **Date:** 2026-11-16 · **Status:** Accepted

**Decision.** After `ADD r8, r8, #1` and `CMP r8, #4`, loop with `BLO PatternCheck`.

**Reasons.** `BNE` would also loop for r8 = 1, 2, 3. But if a bug ever made r8 skip past 4,
`BNE` would keep looping past the end of the table forever. `BLO` stops at any value of 4 or more,
so it fails more safely.

---

## #16: Single `CounterReset` entry point for each scan

- **Date:** 2026-11-16 · **Status:** Accepted

**Decision.** Label `CounterReset` sits above `MOV r8, #0` and below `LDR r1, =RowPatterns`.
After the last row, the code branches to `CounterReset` to start a new scan.

**Reasons.**
- One place starts every scan, so if scan setup grows, it changes in one place only
  (an earlier draft reset r8 in two places).
- The table address never changes, so it is loaded once, above the label, not on every scan.

---

## #17: Test scan logic in the Keil simulator with mapped peripherals

- **Date:** 2026-11-16 · **Status:** Accepted

**Context.** Without the USB cable, the board isn't available. The simulator doesn't model STM32
peripherals, so GPIO accesses gave *error 65: access violation*.

**Decision.** In the simulator's Command window: `MAP 0x40000000, 0x4007FFFF READ WRITE`, then set
IDR by hand with `_WDWORD(0x40020810, value)` to fake keypad states.

**Reasons.** Testing the loop's logic separately from the hardware means a later failure on the
board can only be a hardware or wiring problem.

**Consequences.** In the simulator, IDR is plain memory that starts at 0. Unset, it looks like all
four columns are pressed, so it must be set to `0x000000F0` (no key) first. Every row also sees
the same IDR value, so a fake key press is always reported on row 1.

---

## #18: PIN entry is fixed at 4 digits and auto-submits

- **Date:** 2026-11-16 · **Status:** Accepted

**Decision.** A PIN is exactly 4 digits; entry completes automatically on the 4th digit, with no
`#` needed.

**Open follow-up.** How a user corrects a typo before the 4th digit, and how the PIN is stored so
it can be compared (one comparison or four, and once per stored user).

---

## #19: Attempt counter resets on a correct PIN

- **Date:** 2026-11-16 · **Status:** Accepted

**Reasons.** Prevents carry-over: two typos today shouldn't count against the user tomorrow.

**Open follow-up.** The counter's value after a lockout ends. If it stays at 3, the next wrong
guess immediately triggers another lockout.

---

## #20: Lockout exit condition

- **Date:** 2026-11-16 · **Status:** Resolved by #37

**Context.** Three different exits have been written down so far:
1. Flowchart: a correct password returns to Locked.
2. Notes: wait for the allotted time; no PINs accepted during lockout.
3. Notes: lockout is permanent until the admin password is entered.

**Questions to settle.**
- If PINs are accepted during lockout, can an attacker simply keep guessing?
- If only the admin can clear it, anyone can deliberately lock out legitimate users until the
  admin arrives (a denial-of-service). When is that acceptable?
- The lockout wait must keep watching the lid for tampering, so it can't be a blocking delay loop.

Related open items: what the 30 s "warning delay" after each wrong guess means compared with the
lockout; whether the unlocked state should also re-lock automatically if nobody presses `*`.

---

## #21: Runtime variables in a `READWRITE` RAM area, cleared at startup

- **Date:** 2026-11-17 · **Status:** Accepted

**Context.** The scan loop reuses r7 and r9 on every pass, so typed digits can't be kept in
registers. They need a fixed home in memory.

**Decision.** An `AREA CurrentVariables, DATA, READWRITE` placed after `ENDP`, holding
`PinBuffer` (4 bytes), `DigitCount`, `AttemptCount` and `LockState` (1 byte each). `__main`
clears `PinBuffer` (one `STR`) and `DigitCount` (`STRB`) before anything else runs.

**Reasons.**
- Values that change at run time must be in SRAM (0x2000_0000 region): it is writable with `STR`
  but loses its contents on power-off. Constants such as `RowPatterns` stay in flash
  (0x0800_0000 region): it keeps its contents but can't be written by a normal `STR`.
- Our own `__main` replaces the C library startup, so nothing zeroes RAM for us. Without the clear,
  RAM can power up holding anything, or still hold the last PIN after a jump back to `__main`.

**Consequences.**
- `AREA` is a switch, not a container: putting the data area at the top made every instruction
  after it land in the data area (error A1186E). Data areas go after `ENDP`, before `END`.
- Verified on the board: `PinBuffer` sits at `0x20000004`. The first RAM word belongs to a variable
  from the CubeMX HAL files, so code must always use the label, never a hard-coded address.
- `AttemptCount` and `LockState` are declared but not cleared yet. They must be cleared before
  the lockout logic reads them.

---

## #22: PIN digits stored as ASCII; `*` clears entry

- **Date:** 2026-11-17 · **Status:** Accepted

**Decision.** Each accepted key is stored in `PinBuffer` at position `DigitCount` as its ASCII
character (`'1'` = `0x31`). `*` clears the entry (`DigitCount` = 0). `#` and `A`–`D` are ignored
while a PIN is being typed.

**Reasons.** The same byte can go straight to the LCD and, later, over Wi-Fi, without converting.
`*` as clear answers the typo question left open in #18.

---

## #23: Column decode by searching the `RowPatterns` table

- **Date:** 2026-11-17 · **Status:** Accepted

**Context.** At `KeyFound`, r8 holds the row and r3 holds the column pattern (`0xE`, `0xD`,
`0xB` or `0x7`). The pattern has to become a column number 0–3.

**Decision.** Reuse the `RowPatterns` table: r4 counts 0–3, `LDRB r5,[r1,r4]` loads each entry,
and the loop stops when r5 equals r3. r4 is then the column. Adds r4 (search counter) and r5
(table entry) to the register map in #10.

**Reasons.** A column pattern has the same "one bit low" shape as a row pattern, so one table
serves both. The loop has the same shape as the row scan (counter, `LDRB`, compare, `ADD`,
`CMP #4`, `BLO`).

**Bugs caught while writing it.** `LDR` instead of `LDRB` (#9 again), and a `BLO` with no
`CMP r4,#4` before it, which made it read the flags from `CMP r5,r3`. A branch only reads the
flags left by the last flag-setting instruction.

**Next.** Key number = row × 4 + column (0–15), then a character table indexed by that number.

---

## #24: Multi-key presses rejected by the column search

- **Date:** 2026-11-17 · **Status:** Accepted

**Decision.** If the column search tries all 4 entries with no match, the press is ignored and
the code goes back to `CounterReset`.

**Reasons.** Two keys in the same row pull two column bits low (`1` and `2` together give
`1100`), which matches no single-zero table entry. The rejection costs no extra code.

---

## #25: Key number = row × 4 + column, then a 16-byte ASCII lookup table

- **Date:** 2026-11-17 · **Status:** Accepted

**Decision.** `ADD r7,r4,r8,LSL #2` gives the key number 0–15 in one instruction (row × 4 by a
left shift of 2, plus the column). `LDRB r9,[r11,r7]` then reads the character from
`KeyValues DCB "1","2","3","A", ... "*","0","#","D"`, stored in flash next to `RowPatterns`.
r11 holds the table address, loaded once at setup.

**Reasons.**
- Each row holds 4 keys, so moving down a row adds 4; a shift is cheaper than `MUL`.
- The table stores ASCII directly (#22), so `'6'` comes out as `0x36` with no conversion.
- No terminating 0 byte is needed: the code jumps straight to one position, it never walks the
  string.

**Notes.**
- The same shifted operand means different things: in `LDR r7,[r4,r8,LSL #2]` it builds an
  **address** (that line was tried first and would have read memory at address 6); in `ADD` it is
  a **value**.
- r7 is scratch after the lookup; only r9 (the character) is kept.
- Board: `KeyValues` sits at `0x080002E0`, exactly 4 bytes after `RowPatterns` (`0x080002DC`),
  because the assembler packs an area in order.

---

## #26: Wait for key release, then a 15 ms bounce delay

- **Date:** 2026-11-17 · **Status:** Accepted

**Context.** A full scan takes about 0.75 ms. A normal 250 ms press would be detected about 333
times, filling `PinBuffer` with `6666` and auto-submitting a PIN nobody typed. Separately, switch
contacts bounce for roughly 5–20 ms when they open or close.

**Decision.**
1. `ReleaseWait`: after decoding, keep re-reading IDR (same `AND #0xF0` / `LSR #4` as the scan)
   until the columns read `0xF`. ODR is left alone: the key's row is still driven low.
2. `BounceDelay`: then count down 80,000 (≈ 15 ms).

**Reasons.**
- A fixed delay only guesses how long people hold keys. Waiting for the release **event** works
  for any hold length.
- The release edge can still bounce and look like a new press, and bounce has a known short
  length, so a fixed delay is the right tool there.
- Delay math: `SUBS` + taken `BNE` = 3 cycles × 62.5 ns = 187.5 ns per count;
  15 ms ÷ 187.5 ns = 80,000. That is over 65,535, the largest `MOV` immediate, so it is loaded
  with `LDR r10,=80000` (literal pool).

**Bugs caught while writing it.** Branching back to `KeypadSettle` (a branch goes to a location,
so it would have re-entered the scan), and putting the label on the `LDR` so the count reloaded
every pass and never reached 0. A leftover `KeyReady B KeyReady` placeholder also blocked the
path to `ReleaseWait`.

---

## #27: Accept digits only: `*` first, then a two-compare range check

- **Date:** 2026-11-18 · **Status:** Accepted

**Decision.** After the bounce delay, a `Filter` block runs before anything is stored:
1. `CMP r9,#0x2A` (`*`) → `BEQ ClearPass`
2. `CMP r9,#0x30` → `BLO CounterReset` (below `'0'`)
3. `CMP r9,#0x39` → `BHI CounterReset` (above `'9'`)
4. Otherwise fall through into `StoreDigit`.

**Reasons.**
- Digits `'0'`–`'9'` are consecutive in ASCII (`0x30`–`0x39`), so "is it a digit?" takes two
  compares instead of checking `#`, `A`, `B`, `C`, `D` one by one.
- `*` (`0x2A`) is below `'0'`, so it must be checked first or the range check would discard it.
- `BHI` (strictly higher), not `BHS`: `BHS` would also reject `'9'` itself.

**Bugs caught while writing it.** The checks were first placed after the store, so `#` was saved
before being rejected. A valid digit then fell through into `ClearPass` and wiped the count, and a
`BEQ` immediately followed by `BNE` made `StoreDigit` unreachable. Rule: every block ends in a
branch except one that is meant to fall through.

---

## #28: Stop entry at 4 digits (prevents a buffer overflow)

- **Date:** 2026-11-18 · **Status:** Accepted

**Context.** `StoreDigit` writes to `PinBuffer + DigitCount`. Without a limit, the 5th digit
landed in `DigitCount`, the 6th in `AttemptCount`, the 7th in `LockState`. Nothing in hardware
stops a write past the end of an array.

**Decision.** After saving the count: `CMP r12,#4` → `BEQ PinReady`, otherwise `B CounterReset`.

**Reasons.** Implements the auto-submit from #18 and keeps extra key presses from overwriting the
attempt counter or the lock state, which would be a security bug once lockout exists.

**Follow-up.** `PinReady` must wipe `PinBuffer` and reset `DigitCount` after the PIN check, right
or wrong, or the next attempt starts at 4.

---

## #29: `*` wipes `PinBuffer` as well as resetting `DigitCount`

- **Date:** 2026-11-18 · **Status:** Accepted

**Options.** (1) Reset only `DigitCount`: functionally enough, since stale bytes are overwritten
before the next check. (2) Also zero the buffer.

**Decision.** Option 2: `MOV r12,#0`, `STRB r12,[r2]`, `STR r12,[r6]`.

**Reasons.** A half-typed PIN shouldn't stay readable in RAM. One word store clears all 4 bytes, and
it is safe because `PinBuffer` is exactly 4 bytes and word-aligned. The same word store is not used
for the 1-byte variables, because it would write bytes the code doesn't own.

---

## #30: Clear every RAM variable at startup

- **Date:** 2026-11-18 · **Status:** Accepted

**Context.** On the board, `AttemptCount` and `LockState` read `40 08` after reset: leftover values.
The lockout logic would have started believing there had been 64 failed attempts.

**Decision.** `__main` clears `PinBuffer` (one `STR`) and `DigitCount`, `AttemptCount`, `LockState`
(one `STRB` each). Supersedes the open item in #21.

**Reasons.** Separate `STRB`s write only the bytes this program owns. A single word store at
`DigitCount` would also hit the next byte, which belongs to whatever the linker places there.

---

## #31: One job per reserved register (mask moved from r2 to r7)

- **Date:** 2026-11-18 · **Status:** Accepted

**Context.** r2 held the `0x0000FFFF` mask during GPIO setup and was then reassigned to the
`DigitCount` address. That only worked because setup happened to come first.

**Decision.** The mask now uses scratch register r7. Reserved registers (r0, r1, r2, r6, r11) are set
once and hold one value for the whole program. See the register map in `pinout.md`.

**Note.** With r2, r6 and r11 reserved, no register is fully free. The PIN check and lockout will
need subroutines and the stack (lectures 11–12).

---

## #32: Owner and user roles (TA suggestion)

- **Date:** 2026-11-19 · **Status:** Accepted

**Context.** The TA asked for separate access levels: only the owner can add or remove users, view
the access log and unlock remotely.

**Decision.** Each user has a role: `1` = owner, `0` = user. Slot 0 is the owner by default, but the
role is stored per user rather than implied by position.

**Reasons.**
- Each record states its own permission, so reordering the table can't promote anyone, and more
  than one owner is possible.
- `0` = user means cleared or blank memory falls to the least privilege, never owner.

---

## #33: User table: parallel PIN and role tables, defaults in flash, live copy in RAM

- **Date:** 2026-11-19 · **Status:** Accepted

**Options.**
- (A) Interleaved records: PIN word + role word per user (8-byte stride, `LSL #3`).
- (B) Two parallel tables, `Pins[n]` and `Roles[n]`, one word each (4-byte stride, `LSL #2`).

**Decision.** (B). Flash holds `DefaultPins` (`"6827"`, `"1234"`, `"5678"`, `DCD 0`) and
`DefaultRoles` (`1, 0, 0, 0`). At startup a 4-pass loop copies both into `UserPins` and
`UserRoles` in RAM (16 bytes each), one slot per pass.

**Reasons.**
- (B) is simpler to declare and uses the same `LSL #2` indexing as the rest of the code.
  (A) would also need padding: a 1-byte role makes 5-byte records and breaks word alignment.
- The owner must be able to add and remove users, so the live table has to be writable, which means
  RAM. Flash keeps the defaults.
- The copy loop addresses each table by its own label instead of copying one 32-byte block, so it
  does not depend on the two tables sitting next to each other.
- `ALIGN` before `DefaultPins` and before `UserPins`, because they follow byte-sized data.

**Consequences.** Users added at run time are lost when power drops: the box returns to the defaults.
Acceptable for the demo; persisting them would need flash programming.

---

## #34: Compare a whole PIN as one word; PIN word 0 marks an empty slot

- **Date:** 2026-11-19 · **Status:** Accepted

**Decision.** `LDR r3,[r6]` loads all 4 typed digits as one word; `ConfirmationLoop` loads
`UserPins[slot]` with `LDR r4,[r7,r12,LSL #2]` and compares once per slot. A PIN word of
`0x00000000` means an empty slot.

**Reasons.**
- Possible only because #18 fixes a PIN at exactly 4 ASCII bytes, which is one 32-bit word.
- Little-endian: `"6827"` is `36 38 32 37` in memory and `0x37323836` in a register. Both the typed
  and the stored PIN are loaded the same way, so the byte order cancels out.
- A typed digit is always `0x30`–`0x39`, so a typed PIN word can never be 0. An empty slot can
  therefore never match, with no extra check in the loop.

**Bugs caught while writing it.** The loop first fell through into `Match` when nothing matched, so
a wrong PIN would have unlocked the box; `NoMatch` now sits directly after the loop.

---

## #35: `ActiveRole` variable; `LockState` says whether it is meaningful

- **Date:** 2026-11-19 · **Status:** Accepted

**Context.** The matched role was in a register, and the scan overwrites registers immediately.

**Options.** Reuse `LockState` with 0/1/2 (locked / user / owner), or add a variable.

**Decision.** New `ActiveRole SPACE 1`, cleared at startup. `Match` stores the role there and sets
`LockState` = 1. `ActiveRole` is only meaningful while `LockState` = 1.

**Reasons.** One variable, one meaning. Keeping the table's `0` = user encoding means a cleared
`ActiveRole` is the least privilege, and "nobody" is expressed by `LockState`, not by a role value.

**Bug caught.** `STR` (4 bytes) to `LockState` also overwrote `ActiveRole`, erasing the owner role
right after it was saved. Byte variables use `STRB`.

---

## #36: Keypad behavior by state; lock with lid closed + `#`; auto re-lock

- **Date:** 2026-11-19 · **Status:** Accepted (not implemented yet)

**Decision.**

| State | Keys that act |
|---|---|
| Locked | digits and `*` (PIN entry) |
| Unlocked, user | `#` only |
| Unlocked, owner | `#`, `A` (change a PIN), later `B`/`C`/`D` (add, remove, log) |
| Lockout | digits and `*`; see #37 |

- Locking needs the lid closed **and** `#`. `#` with the lid open is ignored.
- Auto re-lock after a delay with the lid closed and no key, so the box can't stay unlocked because
  someone forgot `#`.

**Reasons.**
- The owner menu runs on the keypad, so it must keep working while the box is unlocked, with the lid
  closed.
- Locking an open lid would drive the bolt into air while the box looks locked.

---

## #37: Lockout: only the owner PIN clears it, with a delay per attempt

- **Date:** 2026-11-19 · **Status:** Accepted (not implemented yet). Resolves #20.

**Decision.** After 3 wrong PINs the box enters lockout. Only a PIN whose role is owner clears it;
a user PIN is refused. Every attempt during lockout waits (about 30 s). Later, the ESP-01 alerts the
owner when a lockout starts.

**Reasons.**
- Like a managed device: after repeated failures, only an administrator restores access.
- Without a delay, lockout would remove the brute-force protection: an attacker could try all 10,000
  owner PINs with no penalty.

**Accepted trade-off.** Anyone can lock legitimate users out until the owner arrives (denial of
service). Acceptable for a personal box with the owner nearby; the Wi-Fi alert makes it practical.

---

## #38: Fail-secure latch; RTC timestamps are a stretch goal

- **Date:** 2026-11-19 · **Status:** Accepted

**Decision.**
- **Fail-secure:** with no power the box stays locked. The latch must rest locked mechanically
  (spring or gravity bolt), with the servo only pulling it open, because an SG90 does not hold its
  position unpowered. The backup is a mechanical key override.
- **Access log** uses sequence numbers for now. Real date and time from the STM32 RTC is a stretch
  goal: it needs a 32.768 kHz crystal (or the less accurate internal clock), a way to set the time,
  and it loses the time on power loss without a backup battery.
- Loss of Wi-Fi is already covered: the lock works fully without it.

