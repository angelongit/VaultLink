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
| 20 | Lockout exit condition | **Open** |

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

- **Date:** 2026-11-16 · **Status:** **Open**

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
