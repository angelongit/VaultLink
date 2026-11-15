	
	
	
	
	AREA KeypadLogic, CODE, READONLY	
	ENTRY
	EXPORT __main
	
__main 	PROC		
	
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
	
	
	
stop B stop



	AREA DATA1, DATA, READONLY
RowPatterns DCB 0xE,0xD,0xB,0x7
	ENDP
	END