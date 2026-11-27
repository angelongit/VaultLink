
	AREA KeypadLogic, CODE, READONLY		
	ENTRY
	
	EXPORT __main
	
ServoLocked EQU 1000
ServoOpen EQU 2000
TimeoutLock EQU 10
__main 	PROC		
	
		;;clearing RAM;;
		LDR r0, =PinBuffer
		MOV r1, #0x0
		STR r1,[r0]
		LDR r0, =DigitCount
		STRB r1,[r0]
		LDR r0, =AttemptCount
		STRB r1,[r0]
		LDR r0,=LockState
		STRB r1,[r0]
		LDR r0,=ActiveRole
		STRB r1,[r0]
		LDR r0,=IdleSeconds
		STRB r1,[r0]
		
		;setting up AHB1ENR
		LDR r0,=0x40023830 ; address of AH1BENR
		LDR r1,[r0] ;read : r1 = whats at/in address at r0
		ORR R1,R1,#7 ; OR with the contents of r1, setting bit 2 and 1(0111) corresponding to GPIOC and GPIOB AND GPIOA
		STR r1,[r0] ;write: putting it back
		
		;;TA PROVIDED CODE;; 
		;;SERVO BRINGUP;;

        LDR R0, =0x40023840; RCC_APB1ENR
		LDR R1,[R0]
		ORR R1,R1,#0x2
		STR R1,[R0]

        ; Configure PA6 as Alternate Function (AF2 for TIM3_CH1)
        LDR R0, =0x40020000      ; GPIOA base address   

        ; Set MODER[13:12] = 10 (AF mode)
        LDR R1, [R0]
        BIC R1, R1, #0x3000                             
        ORR R1, R1, #0x2000                               
        STR R1, [R0]

        ; Set AFRL[27:24] = 0010 (AF2 for PA6)
        LDR R1, [R0, #0x20]
        BIC R1, R1, #0xF000000                               
        ORR R1, R1, #0x2000000                              
        STR R1, [R0, #0x20]

        ; Configure TIM3 for 50Hz PWM
        LDR R0, =0x40000400      ; TIM3 base

        ; Prescaler = 15 (1 microsecond) 19999 (20ms, 50Hz)
        LDR R1, =15
        STR R1, [R0, #0x28]      ; TIM3_PSC

        ; ARR = 1000 ? 1kHz
        LDR R1, =19999	
        STR R1, [R0, #0x2C]      ; TIM3_ARR

        ; CCR1 = 1000 initially
        MOV R1, #ServoLocked
        STR R1, [R0, #0x34]      ; TIM3_CCR1

        ; Set PWM Mode 1 and enable preload
        LDR R1, =0x0060
        ORR R1, R1, #0x0008
        STR R1, [R0, #0x18]      ; TIM3_CCMR1

        ; Enable CH1 output
        MOV R1, #1
        STR R1, [R0, #0x20]      ; TIM3_CCER

        ; Enable ARPE and CEN
        LDR R1, [R0, #0x00]
        ORR R1, R1, #0x81
        STR R1, [R0, #0x00]      ; TIM3_CR1
		
		;; AUTO RELOCK USING SYSTICK;;
		LDR r1,=0xE000E010 ;systick base address
		LDR r3,=15999999 ;1 second per loop, 16Mhz clk - 1
		STR r3,[r1,#0x04] ;loading the reload value 
		MOV r3,#0
		STR r3,[r1,#0x08] ; storing 0 in current value register to clear current count
		MOV r3,#5
		STR r3,[r1,#0x00] ; enabling clock, clksource, and setting it to processor clock
		
		
		;;Setting up I/O in GPIOB 
		
		LDR r0,=0x40020400
		LDR r1,[r0]
		LDR r7,=0x030FFFFF ; cant use this as a constant, loading it into a register due to length
		BIC r1,r1,r7 ;; Clearing lower 20 bits of register and PB12 for lid (input)
		LDR r7,=0x55555 ; 5 = 0101, loading this into register due to length
		ORR r1,r1,r7 ;; setting lower 20 pits as output
		STR r1,[r0] ;; storing in address 
		;;setting up PU/PD
		LDR r0,=0x40020400
		LDR r1,[r0,#0x0C]
		LDR r7,=0x03000000
		BIC r1,r1,r7
		LDR r7,=0x01000000
		ORR r1,r1,r7
		STR r1,[r0,#0x0C]
		
		
		
		BL LCDInit
		
		
		;SEND ENTER
		BL ResetPrompt
		BL UpdateScreen
		;setting up I/O in GPIOC
		
		LDR r0,=0x40020800
		LDR r1,[r0]
		LDR r7,=0x0000FFFF ; cant use this as a constant, loading it into a register due to length
		BIC r1,r1,r7 ;; clearing LOWER 16 bits of register. BIC clears PC0-7
		ORR r1,r1,#0x55 ;; SETTING PC0-3 as output, leaving PC4-7 as input
		STR r1,[r0] ;; storing in address 

		;setting up PUPDR
		LDR r1,[r0,#0x0C] ; address offset for PUPDR
		BIC r1,r1,r7 ;clear lower 16 bits ,same as I/O set up. Reusing value already in r7
		ORR r1,r1,#0x5500 ;setting PC4-7 to pull-up
		STR r1,[r0,#0x0C] ;write back to PUPDR
		
		;; this loop copies default users from flash to a live user table in RAM ;
		LDR r4,=DefaultPins
		LDR r8,=DefaultRoles
		LDR r9,=UserPins
		LDR r10,=UserRoles
		MOV r3,#0
			
CopyLoop
		LDR r5,[r4,r3,LSL#2] ;;LOAD DEFAULT USERS INTO R5
		STR r5,[r9,r3,LSL#2] ;;COPY DEFAULT USERS INTO RAM AT R9
		
		LDR r5,[r8,r3,LSL#2] ;;LOAD DEFAULT ROLES INTO R5
		STR r5,[r10,r3,LSL#2] ;; COPY DEFAULT ROLES INTO RAM AT R10
		
		ADD r3,r3,#1 ;;loop until all four users are added
		CMP r3,#4
		BLO CopyLoop
		
		;; WATCHING FOR INPUT ;; 
		;loop input logic; see notes for register mapping;
		;;this loop scans the keypad for any input. One row is driven low at a time, all columns are read together. 
		;;Depending on if key is pressed or not, jumps to respective branch;;
		;;KeyFound: r3 will hold column pattern, r8 will hold row. This is decoded in the following section;
		;;No key pressed? loop back to patterncheck, if all rows checked branch to CounterReset and start loop over;;
		LDR r1,=RowPatterns ; loading table address into r1
		LDR r2,=DigitCount ;;[r2 = address of DigitCount]
		LDR r6,=PinBuffer ;;[r6 = address of PinBuffer]
		LDR r11,=KeyValues ;; loads address of keyvalues into r11
CounterReset
		LDR r3,=0xE000E010
		LDR r3,[r3]
		TST r3,#0x10000
		BEQ NoTick
Tick
		LDR r3,=LockState
		LDRB r3,[r3]
		CMP r3,#0 ;;check if locked;;
		BEQ NoTick
		CMP r3,#2 ;;check locked
		BEQ NoTick
		
		LDR r7,=IdleSeconds
		LDRB r3,[r7]
		ADD r3,r3,#1
		STRB r3,[r7]
		
		CMP r3,#TimeoutLock
		BHS.W AutoRelock

NoTick
		MOV r8,#0 ;counter register	
			
PatternCheck	
		LDRB r9,[r1,r8] ;;LDRB : each table entry is one byte, writing plain LDR would grab all four of our table entries; ;;lookup;;
		LDR r7,[r0,#0x14] ;; writing ODR contents to scratch register to modify ;;read
		BIC r7,r7,#0xF ;; clearing first 4 bits
		ORR r7,r9,r7 ; copies 1's from current table value into modified ODR
		STR r7,[r0,#0x14] ;; writing back modified ODR to original ODR ;;write
		
		;;countdown;;
		MOV r10,#1000
KeypadSettle	SUBS r10,r10,#1
		BNE KeypadSettle
		
		;;idr;;
		LDR r7,[r0,#0x10] ;; read GPIOC IDR 
		AND r3,r7,#0xF0 ;; clearing everything except bits 4-7
		LSR r3, r3, #4 ;; this line shifts the IDR bits 4-7 to 0-3 to simplify comparison with key pattern (0xE0 vs 0xE)
		
		;; comparison ;; 
		CMP r3,#0xF ;; "was anything pressed?"
		BNE KeyFound
		
		;; NO KEY PRESSED;;
		ADD r8,r8,#1 ;;increment counter
		CMP r8,#4 ;; check if all table values have been parsed;;
		BLO PatternCheck ;;continue through table if not;;
		
		B CounterReset ;; if counter = 4, reset counter and keep looping


	;;Finding Column / Key ; 
KeyFound	MOV r4,#0
SearchingTable	LDRB r5,[r1,r4]
	CMP r5,r3 ; [r5 = currentpattern being evaluated, r3 = column pattern]
	BEQ ColumnFound
	ADD r4,r4,#1 ; [r4 = increment counter] 
	CMP r4,#4
	BLO SearchingTable
	B CounterReset
	

	;; Finding actual key ;;
ColumnFound
	ADD r7,r4,r8,LSL#2 ; this part determined position we are in by shifting performing column + row*4. See notes for derivation. [r8 = counter for row number (0-3]
	LDRB r9,[r11,r7] ; [r9 = character ASCII, r11 = key values address]

	;;wait until key is released, if held do not input until release;
ReleaseWait
		LDR r7,[r0,#0x10] ;; read GPIOC IDR [r0 = base address, r7 = scratch register]
		AND r3,r7,#0xF0 ;; clearing everything except bits 4-7 [r3 = column bits]
		LSR r3, r3, #4 ;; this line shifts the IDR bits 4-7 to 0-3 to simplify comparison with key pattern (0xE0 vs 0xE)
		
		;; comparison ;; 
		CMP r3,#0xF ;; "still holding?"
		BNE ReleaseWait
		LDR r10,=80000 ; [r10 = countdown delay]
		;;loop
BounceDelay
		SUBS r10,r10,#1
		BNE BounceDelay
		

	;;accounting for edgecases;;
Filter
	LDR r3,=IdleSeconds ;;if any button pressed, reset idle second counter to 0;
	MOV r7,#0
	STRB r7,[r3]
	LDR r3,=LockState
	LDRB r3,[r3]
	CMP r3,#1
	BEQ UnlockedKeys
	CMP r3,#2
	BHI AdminKeys
LockedKeys
	CMP r9,#0x2A;;if r9 holds '*', go to clear routine
	BEQ ClearPass
	CMP r9,#0x30 ;;"Is character lower than 0? invalid"
	BLO CounterReset
	CMP r9,#0x39 ;;"Is character highter than 9? invalid"
	BHI CounterReset
	
	B StoreDigit
	
AdminKeys
	CMP r9,#0x23 ;; check if "#" is pressed, relock box and exit menu
	BEQ LockBox
	CMP r3,#0x3
	BHI LockedKeys
	CMP r9,#0x42 ;; check if "B" is pressed, put box in 'away' mode
	BEQ.W AwayMode
	CMP r9,#0x43 ;; check if "C" is precced, setup for adding a password
	BEQ.W AddUser ;; Target branch out of 16-bit range so .W append forces 32 bit encoding
	CMP r9,#0x44 ;;Check if "D" is pressed, setup for deleting password
	BEQ.W DeleteUser
	B CounterReset ;;ignore any key that isnt listed in the menu;
	
	
StoreDigit
	LDRB r12,[r2] ;;[r12 = digits stored so far]	
	STRB r9,[r6,r12];;storing ASCII value into PinBuffer with an offset of current byte
	ADD r12,r12,#1;; increment at r12, accounting for next bite
	STRB r12,[r2] ;; save new count back to RAM
	MOV r3,#0x2A ;moving "*" into r3
	BL LCDChar ; printing r3 when a number is typed
	CMP r12,#4
	BEQ PinReady
	B CounterReset
	
ClearPass
	MOV r12,#0 ;loading 0 in r12 for clearing purposes
	STRB r12,[r2] ;clearing DigitCount to 0
	STR r12,[r6] ;; clearing pin itself
	BL UpdateScreen
	B CounterReset ;restart search
	
UnlockedKeys
	CMP r9,#0x23;;# check for lock;
	BEQ LockBox
	CMP r9,#0x42;;Bcheck for admin
	BEQ ActiveRoleCheck
	B CounterReset
	
;; this block locks the box if '#' is pressed
LockBox
	LDR r3,=LockState
	BL SecureBox
	CMP r5,#0
	BNE.W LidOpenMsg
	MOV r5,#0
	STRB r5,[r3] ;;insert 0 into LockState, forcing the box to lock [0 = Locked, 1 = Unlocked]
	B ClearPass
;; this press checks users privilige if 'B'is pressed[0= User, 1 =Admin]
ActiveRoleCheck
	LDR r3,=ActiveRole
	LDRB r3,[r3]
	CMP r3,#1
	BNE CounterReset

	B OwnerMenu

PinReady 
	LDR r3,=LockState
	LDRB r3,[r3]
	CMP r3,#4
	BEQ.W SaveUser
	CMP r3,#5
	BEQ.W RemoveUser
	LDR r3,[r6] ;;loading live pin at r3 for comparison later
	LDR r7,=UserPins ;;storing address of live pins in scratch;
	LDR r10,=UserRoles ;;storing address of live roles in scratch;
	MOV r12,#0
	
;;this loop sorts four times to check if the pin entered matches any of the actual pins
ConfirmationLoop
	LDR r4,[r7,r12,LSL#2]
	CMP r4, r3
	BEQ Match
	ADD r12,r12,#1
	CMP r12,#4
	BLO ConfirmationLoop
	
NoMatch ;;if pins dont match, come here to increment attempt # and check if lockout is prompted;;
	LDR r7,=AttemptCount
	LDRB r12,[r7]
	ADD r12,r12,#1
	STRB r12,[r7]
	CMP r12,#3
	BHS LockOut
	B ClearPass
LockOut
	LDR r7,=LockState
	MOV r12,#2
	STRB r12,[r7]
	B LockoutDelay

Match ;;CHECKING IF PASSWORDS MATCH TO EITHER MOVE TO UNLOCK OR LOCKOUT
	LDR r3,[r10,r12,LSL#2]
	
	LDR r7,=LockState
	LDRB r4,[r7]
	CMP r4,#2 ;THIS CHECKS IF LOCKSTATE IS IN #2, [LOCKOUT = 2]
	BNE NormalUnlock
	
	CMP r3,#1
	BNE LockoutDelay


	
NormalUnlock ;; standard unlock procedure ;;
	LDR r7,=ActiveRole
	STRB r3,[r7] ;;check users role ;;
	LDR r7,=AttemptCount 
	MOV r12,#0 
	STRB r12,[r7] ;;clear attempt count;;
	LDR r7,=LockState
	MOV r12,#1
	STRB r12,[r7] ;; [UNLOCKED STATE = 1]
	BL OpenBox
	B ClearPass
	
LockoutDelay
	BL UpdateScreen
	MOV r12,#0 ;loading 0 in r12 for clearing purposes
	STRB r12,[r2] ;clearing DigitCount to 0
	STR r12,[r6] ;; clearing pin itself
	LDR r10,=120000000 ;; 30s delay
	
LDelay	;delay loop
	SUBS r10,r10,#1
	BNE LDelay
	B ClearPass

	
OwnerMenu
	LDR r7,=LockState
	MOV r12,#3
	STRB r12,[r7] ;; [OWNER MENU STATE = 3]
	B ClearPass
	
AwayMode
	BL SecureBox 
	CMP r5,#0
	BNE LidOpenMsg
	MOV r3,#2
	LDR r7,=LockState
	STRB r3,[r7]
	MOV r3,#3
	LDR r7,=AttemptCount
	STRB r3,[r7]
	B ClearPass	

AutoRelock
	BL SecureBox
	CMP r5,#0
	BEQ Locked
	;;lid open path;;
	;;add buzzer here;;
	LDR r3,=IdleSeconds
	MOV r7,#TimeoutLock
	STRB r7,[r3]
	B CounterReset
	
	;; lid closed
Locked
	LDR r3,=IdleSeconds ;;if any button pressed, reset idle second counter to 0;
	MOV r7,#0
	STRB r7,[r3]
	MOV r5,#0
	LDR r3,=LockState
	STRB r5,[r3] ;;insert 0 into LockState, forcing the box to lock [0 = Locked, 1 = Unlocked]
	B ClearPass
	


AddUser
	BL FindEmptySlot
	CMP r12,#4
	BHS AddFull
	LDR r7,=LockState
	MOV r12,#4
	STRB r12,[r7] 
	B ClearPass

DeleteUser
	BL FindUsedSlot
	CMP r12,#4
	BHS DelNone
	LDR r7,=LockState
	MOV r12,#5
	STRB r12,[r7] 
	B ClearPass
	
AddFull
	LDR r7,=OptionFull
	BL ShowMessage
	B ClearPass
DelNone
	LDR r7,=OptionNone
	BL ShowMessage
	B ClearPass
DelDenied
	LDR r7,=OptionDenied
	BL ShowMessage
	B ClearPass
LidOpenMsg
	LDR r7,=StateLidOpen
	BL ShowMessage
	B ClearPass
	
SaveUser
	LDR r3,=LockState
	MOV r7,#3
	STRB r7,[r3]
	LDR r3,[r6]
	BL FindPin
	CMP r12,#4
	BLO PinExists
	BL FindEmptySlot
	CMP r12,#4
	BHS AddFull
	LDR r10,=UserPins
	STR r3,[r10,r12,LSL#2]
	MOV r3,#0
	LDR r10,=UserRoles
	STR r3,[r10,r12,LSL#2]	
	B ClearPass

RemoveUser
	LDR r3,=LockState
	MOV r7,#3
	STRB r7,[r3]
	LDR r3,[r6]
	BL FindPin
	CMP r12,#4
	BHS DelNone
	CMP r12,#0
	BEQ	 DelDenied
	MOV r3,#0
	LDR r10,=UserPins
	STR r3,[r10,r12,LSL#2]
	B ClearPass

	
	
PinExists
	LDR r7,=OptionExists
	BL ShowMessage
	B ClearPass
	
	
	
	
	
	ENDP
	LTORG


;;; FUNCTION AREA;;



LCDCommand  FUNCTION ; COMMAND BYTE IN R3, PRESERVES ALL REGISTERS. Handles all the low and high signals for R and E
	STMDB SP!,{r5,r7,LR} ; saves r5,r7, and treturn address
	LDR r5,=0x40020400 ;;load GPIOB base in r5
	STRB r3,[r5,#0x14] ;;copies one byte from r3 into memory [command byte onto PB0-PB7]
	MOV r7, #2 ; sets bit 1 (E) and clears bit 0 (R) 
	STRB r7,[r5,#0x15] ; this changes only PB8-PB15 so E=1 and R=0
	BL delay	
	MOV r7, #0
	STRB r7,[r5,#0x15] ; E = 0, R = 0 falling edge, LCD updates
	LDMIA SP!,{r5,r7,PC}
	ENDP

LCDChar  FUNCTION  ;; character byte in r3
	STMDB SP!,{r5,r7,LR} ; saves r5,r7, and treturn address
	LDR r5,=0x40020400 ;;load GPIOB base in r5
	STRB r3,[r5,#0x14] ;;copies one byte from r3 into memory [command byte onto PB0-PB7]
	MOV r7, #3 ; sets bit 0 and 1 [E and R]
	STRB r7,[r5,#0x15] ; this changes only PB8-PB15 so E=1 and R=1
	BL delay	
	MOV r7, #1 ; sets bit 0 [R] and clears bit 1 [E]
	STRB r7,[r5,#0x15] ; E = 0, R = 1 
	LDMIA SP!,{r5,r7,PC}
	ENDP

LCDInit		FUNCTION
	STMDB SP!,{r3,r7,LR}	
	MOV r7,#5
	
powerupdelay
	BL delay
	SUBS r7,r7,#1	
	BNE powerupdelay
	
	MOV R3, #0x38	; 2 lines, 7x5 characters, 8-bit mode		 
	BL LCDCommand	; Send command in R3 to LCD
	
	; ADD INSTRUCTIONS TO TURN ON THE DISPLAY AND THE CURSOR,
	MOV R3, #0x0F ;Turn ON Display and Cursor
	BL LCDCommand ; send to our subroutine to place it in the proper register
	MOV R3, #0x01 ; clear display screen
	BL LCDCommand
	MOV R3, #0x06 ; Increment Cursor (automatically shift cursor one place to right)
	BL LCDCommand 
	; CLEAR DISPLAY AND MOVE CURSOR RIGHT
				
	LDMIA SP!,{r3,r7,LR}			
	BX LR
	ENDP
		
		
delay FUNCTION
	STMDB SP!,{r10}
	LDR r10,=12000
LCDloop
	SUBS r10,r10,#1
	BNE LCDloop
	LDMIA SP!,{r10}
	BX LR
	ENDP

LCDString	FUNCTION
	STMDB SP!,{r3,r7,LR}
loopload
	LDRB r3,[r7],#1
	CMP r3,#0
	BEQ restorestring
	BL LCDChar
	B loopload
restorestring
	LDMIA SP!,{r3,r7,PC}
	ENDP
		
ResetPrompt FUNCTION
	STMDB SP!,{r3,r7,LR}
	MOV r3, #0x01 
	LDR r7,=MessagePin
	BL LCDCommand 
	BL LCDString 
	LDMIA SP!,{r3,r7,PC}
	ENDP
		
ShowMessage FUNCTION
	STMDB SP!,{r3,r7,r12,LR}
	MOV r3,#0x01
	BL LCDCommand	
	LDR r12,=4000000
	BL LCDString
msgloop	
	SUBS r12,r12,#1
	BNE msgloop


	LDMIA SP!,{r3,r7,r12,PC}
	ENDP
		
UpdateScreen FUNCTION
	STMDB SP!,{r3,r7,LR}
	LDR r3,=LockState ;;address of lockstate
	LDRB r3,[r3] ;;actual state of lock loaded into r3
	CMP r3,#1 ;;if open -> print open
	BEQ ScreenOpen
	CMP r3,#2 ;if lockoed out -> print lockout
	BEQ ScreenLockout
	CMP r3,#3
	BEQ ScreenAdmin
	CMP r3,#4
	BEQ ScreenAdd	
	CMP r3,#5
	BEQ ScreenDel
	

ScreenLocked
	BL ResetPrompt
	MOV r3, #0xC0
	LDR r7,=MessageLocked
	BL LCDCommand
	BL LCDString
	MOV r3,#0x84
	BL LCDCommand
	B ScreenDone
	
ScreenOpen
	BL ResetPrompt
	MOV r3, #0xC0
	LDR r7,=MessageOpen
	BL LCDCommand
	BL LCDString
	B ScreenDone
	
ScreenLockout
	BL ResetPrompt
	MOV r3, #0xC0
	LDR r7,=MessageLockout
	BL LCDCommand
	BL LCDString
	MOV r3,#0x84
	BL LCDCommand
	B ScreenDone
	
ScreenAdmin
	MOV r3, #0x01
	BL LCDCommand
	LDR r7,=OptionAddDel
	BL LCDString
	MOV r3,#0xC0
	LDR r7,=OptionAway
	BL LCDCommand
	BL LCDString
	B ScreenDone

ScreenAdd
	BL ResetPrompt
	MOV r3,#0xC0
	LDR r7,=OptionAdd
	BL LCDCommand
	BL LCDString
	MOV r3,#0x84
	BL LCDCommand
	B ScreenDone
	
ScreenDel
	BL ResetPrompt
	MOV r3,#0xC0
	LDR r7,=OptionDel
	BL LCDCommand
	BL LCDString
	MOV r3,#0x84
	BL LCDCommand
	B ScreenDone
	
	
ScreenDone
	LDMIA SP!,{r3,r7,PC}	
	ENDP

;; returns r5:0 = locked, r5:1 = lid open
SecureBox FUNCTION
	STMDB SP!,{r3,r7,r12,LR}
	;;lid check here, return 1 if open;d
	LDR r3, =0x40020400
	LDR r7,[r3,#0x10]
	MOV r12,#0x1000
	AND r7,r7,r12
	CMP r7,#0
	BNE LidOpen
	LDR r3, =0x40000400 
	MOV r7,#ServoLocked
	STR r7,[r3,#0x34]
	MOV r5,#0
	B SecureDone
LidOpen
	MOV r5,#1
SecureDone
	LDMIA SP!,{r3,r7,r12,PC}
	ENDP
		
;; moves latch open, no return;;
OpenBox FUNCTION
	STMDB SP!,{r3,r7,LR}
	LDR r3, =0x40000400 
	MOV r7,#ServoOpen
	STR r7,[r3,#0x34]
	LDMIA SP!,{r3,r7,PC}
	ENDP
		
;; RETURNS R12: slots 0-3 , or 0xFF is table is full
FindEmptySlot FUNCTION
	STMDB sp!,{r3,r5,LR}
	LDR r3,=UserPins ;;userpins base address
	MOV r12,#0 ;;counter register
SlotLoop	
	LDR r5,[r3,r12,LSL#2]
	CMP r5,#0
	BEQ SlotDone
	ADD r12,r12,#1
	CMP r12,#4
	BLO SlotLoop
	MOV r12,#0xFF
SlotDone
	LDMIA SP!,{r3,r5,PC}
	ENDP
;;RETURNS R12: slots 1-3 or 0xFF if there are no slots taken.
FindUsedSlot FUNCTION
	STMDB sp!,{r3,r5,LR}
	LDR r3,=UserPins ;;userpins base address
	MOV r12,#1 ;;counter register, admin pin cannot be deleted so it starts at 1
SlotLoop2	
	LDR r5,[r3,r12,LSL#2]
	CMP r5,#0
	BNE SlotDone2
	ADD r12,r12,#1
	CMP r12,#4
	BLO SlotLoop2
	MOV r12,#0xFF
SlotDone2
	LDMIA SP!,{r3,r5,PC}
	ENDP

;; Input r3 = PIN , returns r12 = slots 0-3 [where it was found], or 0xFF IF NOT IN TABLE
FindPin FUNCTION
	STMDB sp!,{r3,r5,r7,LR}
	LDR r7,=UserPins
	MOV r12,#0
PinLoop	
	LDR r5,[r7,r12,LSL#2]
	CMP r5,r3
	BEQ PinFound
	ADD r12,r12,#1
	CMP r12,#4
	BLO PinLoop
	MOV r12,#0xFF
PinFound
	LDMIA sp!,{r3,r5,r7,PC}
	
	ENDP
		
		
		
		
		
		
	AREA Keypad, DATA, READONLY
RowPatterns DCB 0xE,0xD,0xB,0x7 ; determining row key is on via 0 bit
KeyValues DCB "1","2","3","A","4","5","6","B","7","8","9","C","*","0","#","D"
	ALIGN
DefaultPins DCB "6827","1234","5678"
	DCD 0
DefaultRoles DCD 0x1,0x0,0x0,0x0
MessagePin DCB "PIN:",0
MessageOpen DCB "OPEN",0
MessageLocked DCB "LOCKED",0
MessageLockout DCB "LOCKOUT",0
OptionAddDel DCB "C:+  D:-",0
OptionAway DCB "B:Away",0
OptionFull DCB "FULL",0
OptionAdd DCB "ADD USER",0
OptionDel DCB "DELETE",0
OptionExists DCB "EXISTS",0
OptionNone DCB "NO USERS",0
OptionDenied DCB "DENIED",0
StateLidOpen DCB "LID OPEN",0

	AREA CurrentVariables, DATA, READWRITE
PinBuffer SPACE 4 ;holds pin digits typed so far
DigitCount SPACE 1 ; how many digits are in PinBuffer
AttemptCount SPACE 1;
IdleSeconds SPACE 1;
LockState SPACE 1;	
ActiveRole SPACE 1;
	ALIGN
UserPins SPACE 16
UserRoles SPACE 16
	END
	