
	AREA KeypadLogic, CODE, READONLY		
	ENTRY
	
	EXPORT __main
	
__main 	PROC		
	
	
	
		;;clearing RAM;;
		LDR r0, =PinBuffer
		MOV r1, #0x0
		STR r1,[r0]
		LDR r0, =DigitCount
		STRB r1,[r0]
		
		;setting up AHB1ENR
		LDR r0,=0x40023830 ; address of AH1BENR
		LDR r1,[r0] ;read : r1 = whats at/in address at r0
		ORR R1,R1,#4 ; OR with the contents of r1, setting bit 2 (0100) to 1 corresponding to GPIOC
		STR r1,[r0] ;write: putting it back

		;setting up I/O
		LDR r0,=0x40020800
		LDR r1,[r0]
		LDR r2,=0x0000FFFF ; cant use this as a constant, loading it into a register due to length
		BIC r1,r1,r2 ;; clearing LOWER 16 bits of register. BIC clears PC0-7
		ORR r1,r1,#0x55 ;; SETTING PC0-3 as output, leaving PC4-7 as input
		STR r1,[r0] ;; storing in address 

		;setting up PUPDR
		LDR r1,[r0,#0x0C] ; address offset for PUPDR
		BIC r1,r1,r2 ;clear lower 16 bits ,same as I/O set up. Reusing value already in r2
		ORR r1,r1,#0x5500 ;setting PC4-7 to pull-up
		STR r1,[r0,#0x0C] ;write back to PUPDR
		
		;; WATCHING FOR INPUT ;; 
		;loop input logic; see notes for register mapping;
		;;this loop scans the keypad for any input. One row is driven low at a time, all columns are read together. 
		;;Depending on if key is pressed or not, jumps to respective branch;;
		;;KeyFound: r3 will hold column pattern, r8 will hold row. This is decoded in the following section;
		;;No key pressed? loop back to patterncheck, if all rows checked branch to CounterReset and start loop over;;
		LDR r1,=RowPatterns ; loading table address into r1
		LDR r11,=KeyValues
CounterReset
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
	CMP r5,r3
	BEQ ColumnFound
	ADD r4,r4,#1
	CMP r4,#4
	BLO SearchingTable
	B CounterReset
	

	;; Finding actual key ;;
ColumnFound
	ADD r7,r4,r8,LSL#2
	LDRB r9,[r11,r7]


ReleaseWait
		LDR r7,[r0,#0x10] ;; read GPIOC IDR 
		AND r3,r7,#0xF0 ;; clearing everything except bits 4-7
		LSR r3, r3, #4 ;; this line shifts the IDR bits 4-7 to 0-3 to simplify comparison with key pattern (0xE0 vs 0xE)
		
		;; comparison ;; 
		CMP r3,#0xF ;; "still holding?"
		BNE ReleaseWait
		LDR r10,=80000
		;;loop
BounceDelay
		SUBS r10,r10,#1
		BNE BounceDelay
		
wait B wait

	ENDP
		


	AREA DATA1, DATA, READONLY
RowPatterns DCB 0xE,0xD,0xB,0x7 ; determining row key is on via 0 bit
KeyValues DCB "1","2","3","A","4","5","6","B","7","8","9","C","*","0","#","D"
	AREA CurrentVariables,DATA, READWRITE
PinBuffer SPACE 4 ;holds pin digits typed so far
DigitCount SPACE 1 ; how many digits are in PinBuffer
AttemptCount SPACE 1;
LockState SPACE 1;	

	END
	