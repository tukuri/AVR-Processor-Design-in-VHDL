;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; Amtel AVR Test Code
; 
; This is the test code for the AVR design. It exercises the various 
; instructions implemented in the design, allowing the functionality to be 
; verified by observing the program address bus, the program data bus, the data 
; address bus, and the data data bus.
; Observe the instruction results and flags by PUSHing the registers and POPing them. 
; PUSH instruction allows observing the values by loading them on data bus.
; To observe flags, we first use IN instruction to load the flags to a general register(r10), 
; and then PUSH the register so that we can observe the flags on data bus.
; Status Register(SREG, 8-bit) : ITHSVNZC
; Revision History:
;	  22 Jan 19	   Sung Hoon Choi		  Created
;	  22 Jan 19    Sung Hoon Choi         Added ALU tests, branch tests, and skip tests
;	  23 Jan 19    Sung Hoon Choi		  Revised the test code to use IN instruction 
;										  to fetch and observe the flags.
;     24 Jan 19    Garret Sullivan        Added data memory access tests
; 	  24 Jan 19    Sung Hoon Choi		  Added more test cases for ALU ops
;     24 Feb 19    Sung Hoon Choi		  Updated R/W data memory access for ALU ops
;     25 Feb 19    Sung Hoon Choi		  Fixed bugs in flow control
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.equ SREG = 0x3f

; Initialize all status register into zeros.
BCLR    0                      
BCLR    7                   
BCLR    4                  
BCLR    3                    
BCLR    1                     
BCLR    5                     
BCLR    2                       
BCLR    6                       

; test load immediate, push, and pop (SP=0 will loop to FFFF)
; test load immediate, push, and pop
test_ldi_push_pop:
	ldi r16, $7E   ; r16=7E
	ldi r17, $F8   ; r17=F8
	ldi r18, $2C   ; r18=2C
	push r16       ;W 7E FFFF
	push r17       ;W F8 FFFE
	push r18       ;W 2C FFFD
	pop r18        ;R 2C FFFD
	pop r17        ;R F8 FFFE
	pop r16        ;R 7E FFFF


; test store indirect
test_st:
	ldi r27, $FF   ; setting X
	ldi r26, $00   ; X = FF00
	st X, r16      ;W 7E FF00

	ldi r29, $FF   ; setting Y
	ldi r28, $80   ; Y = FF80
	st Y, r17      ;W F8 FF80

	ldi r31, $FF   ; setting Z
	ldi r30, $B0   ; Z = FFB0
	st Z, r18      ;W 2C FFB0


; test store indirect with post increment
test_st_inc:
	st X+, r18     ;W 2C FF00
	st X+, r17     ;W F8 FF01
	st X+, r16     ;W 7E FF02

	st Y+, r18     ;W 2C FF80
	st Y+, r17     ;W F8 FF81
	st Y+, r16     ;W 7E FF82

	st Z+, r18     ;W 2C FFB0
	st Z+, r17     ;W F8 FFB1
	st Z+, r16     ;W 7E FFB2


; test store indirect with pre-decrement
test_st_dec:
	st -X, r18     ;W 2C FF02
	st -X, r17     ;W F8 FF01
	st -X, r16     ;W 7E FF00

	st -Y, r17     ;W F8 FF82
	st -Y, r16     ;W 7E FF81
	st -Y, r18     ;W 2C FF80

	st -Z, r16     ;W 7E FFB2
	st -Z, r18     ;W 2C FFB1
	st -Z, r17     ;W F8 FFB0


; test load indirect
test_ld:
	ld r19, X      ;R 7E FF00
	push r19       ;W 7E FFFF
	pop r19        ;R 7E FFFF

	ld r20, Y      ;R 2C FF80
	push r20       ;W 2C FFFF
	pop r20        ;R 2C FFFF

	ld r21, Z      ;R F8 FFB0
	push r21       ;W F8 FFFF
	pop r21        ;R F8 FFFF


; test load indirect with post-increment
test_ld_inc:
	ld r19, X+     ;R 7E FF00
	ld r19, X+     ;R F8 FF01

	ld r20, Y+     ;R 2C FF80
	ld r20, Y+     ;R 7E FF81

	ld r21, Z+     ;R F8 FFB0
	ld r21, Z+     ;R 2C FFB1


; test load indirect with pre-decrement
test_ld_dec:
	ld r19, -X     ;R F8 FF01
	ld r19, -X     ;R 7E FF00

	ld r20, -Y     ;R 7E FF81
	ld r20, -Y     ;R 2C FF80

	ld r21, -Z     ;R 2C FFB1
	ld r21, -Z     ;R F8 FFB0


; test store indirect with offset
test_std:
	std Y+2, r20   ;W 2C FF82
	std Z+2, r21   ;W F8 FFB2


; test load indirect with offset
test_ldd:
	ldd r20, Y+1   ;R 7E FF81
	ldd r21, Z+1   ;R 2C FFB1


; test store direct
test_sts:
	sts $FF02, r19 ;W 7E FF02


; test load direct
test_lds:
	lds r19, $FF01 ;R F8 FF01


; test move
test_mov:
	ldi r16, $11   ; r16=11
	ldi r17, $38   ; r17=38
	mov r16, r17   ; r16=38
	push r16       ;W 38 FFFF
	pop r16        ;R 38 FFFF

;;; test BSET, BCLR, BRBS, BRBC, and IN ;;;
test_BSET0:
	BSET 0 ; C = 1
	IN r10, SREG ; Flags are -------1. Load the status register to r10.
	PUSH r10 ;W 01 FFFF
	POP r10  ;R 01 FFFF
	BRBS 0, test_BCLR0 ; if C = 1, skip NOP
	NOP 
test_BCLR0:
	BCLR 0 ; C = 0
	IN r10, SREG ; Flags are -------0
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 0, test_BSET1 ; if C = 0, skip NOP
	NOP
test_BSET1:
	BSET 1 ; Z = 1
	IN r10, SREG ; Flags are ------1-
	PUSH r10 ;W 02 FFFF
	POP r10  ;R 02 FFFF
	BRBS 1, test_BCLR1 ; if Z = 1, skip NOP
	NOP 
test_BCLR1:
	BCLR 1	; Z = 0
	IN r10, SREG; Flags are -------0-
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 1, test_BSET2 ; if Z = 0, skip NOP
	NOP
test_BSET2:
	BSET 2 ; N = 1
	IN r10, SREG ; Flags are -----1--
	PUSH r10 ;W 04 FFFF
	POP r10  ;R 04 FFFF
	BRBS 2, test_BCLR2 ; if N = 1, skip NOP
	NOP 
test_BCLR2:
	BCLR 2	; N = 0
	IN r10, SREG; Flags are ------0--
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 2, test_BSET3 ; if N = 0, skip NOP
	NOP
test_BSET3:
	BSET 3 ; V = 1
	IN r10, SREG ; Flags are ----1---
	PUSH r10 ;W 08 FFFF
	POP r10  ;R 08 FFFF
	BRBS 3, test_BCLR3 ; if V = 1, skip NOP
	NOP 
test_BCLR3:
	BCLR 3	; V = 0
	IN r10, SREG; Flags are -----0---
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 3, test_BSET4 ; if V = 0, skip NOP
	NOP
test_BSET4:
	BSET 4 ; S = 1
	IN r10, SREG ; Flags are ---1----
	PUSH r10 ;W 10 FFFF
	POP r10  ;R 10 FFFF
	BRBS 4, test_BCLR4 ; if S = 1, skip NOP
	NOP 
test_BCLR4:
	BCLR 4	; S = 0
	IN r10, SREG; Flags are ---0-----
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 4, test_BSET5 ; if S = 0, skip NOP
	NOP
test_BSET5:
	BSET 5 ; H = 1
	IN r10, SREG ; Flags are --1-----
	PUSH r10 ;W 20 FFFF
	POP r10  ;R 20 FFFF
	BRBS 5, test_BCLR5 ; if H = 1, skip NOP
	NOP 
test_BCLR5:
	BCLR 5	; H = 0
	IN r10, SREG; Flags are --0------
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 5, test_BSET6 ; if H = 0, skip NOP
	NOP
test_BSET6:
	BSET 6 ; T = 1
	IN r10, SREG ; Flags are -1------
	PUSH r10 ;W 40 FFFF
	POP r10  ;R 40 FFFF
	BRBS 6, test_BCLR6 ; if T = 1, skip NOP
	NOP 
test_BCLR6:
	BCLR 6	; T = 0
	IN r10, SREG; Flags are -0-------
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 6, test_BSET7 ; if T = 0, skip NOP
	NOP
test_BSET7:
	BSET 7 ; I = 1
	IN r10, SREG ; Flags are 1-------
	PUSH r10 ;W 80 FFFF
	POP r10  ;R 80 FFFF
	BRBS 7, test_BCLR7 ; if I = 1, skip NOP
	NOP 
test_BCLR7:
	BCLR 7	; I = 0
	IN r10, SREG; Flags are 0--------
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	BRBC 7, test_ADC ; if I = 0, skip NOP
	NOP

;;;; test ADC (Add with Carry) ;;;;
test_ADC:
	LDI r16, $1E	; r16 = $1E
	LDI r20, $1B	; r20 = $1B
	BSET 0		;  C = 1
	ADC r16, r20	; r16($3A) = r1($1E) + r0($1B) + C(1)
	PUSH r16 ;W 3A FFFF
	POP r16  ;R 3A FFFF
	IN r20, SREG
	PUSH r20    ;W 20 FFFF
	POP r20		;R 20 FFFF

	LDI r16, $1E	; r16 = $1E
	LDI r20, $1B	; r20 = $1B
	BCLR 0		;  C = 0
	ADC r16, r20	; r16($39) = r16($1E) + r20($1B) + C(0)
	PUSH r16     ;W 39 FFFF
	POP r16      ;R 39 FFFF
	IN r20, SREG
	PUSH r20	;W 20 FFFF
	POP r20		;R 20 FFFF

	LDI r16, $7F ; r1 = b01111111
	LDI r20, $7F ; r0 = b01111111
	BCLR 0		; C = 0
	ADC r16, r20  ; r1 = r1($7F) + r0($7F) + 0 = b11111110 = -2. Overflow
	PUSH r16     ;W FE FFFF
	POP r16      ;R FE FFFF
	IN r20, SREG
	PUSH r20    ;W 2C FFFF
	POP r20     ;R 2C FFFF

;;; test ADD (Add without Carry) ;;;
test_ADD:
	BSET 0		; C = 1
	LDI r16, $34	; r16 = $34 
	LDI r20, $09	; r20 = $09
	ADD r16, r20	; r16($3D) = r16($34) + r20($09)
	PUSH r16     ;W 3D FFFF
	POP r16      ;R 3D FFFF 
	IN r20, SREG
	PUSH r20	;W 00 FFFF
	POP r20		;R 00 FFFF
	
	BCLR 0		; C = 0
	LDI r16, $80	; r16 = b10000000 = -128
	LDI r20, $80	; r20 = b10000000 = -128
	ADD r16, r20	; r16 = r16 + r20
	PUSH r16     ;W 00 FFFF
	POP r16      ;R 00 FFFF
	IN r20, SREG
	PUSH r20	;W 1B FFFF
	POP r20		;R 1B FFFF

;;;	test ADIW (Add Immediate to Word) ;;;
test_ADIW:
	LDI r25, $F0
	LDI r24, $E0
	ADIW r25:r24, 3	; Add 3 to r25:r24.
	PUSH r25	;W F0 FFFF
	POP r25		;R F0 FFFF
	PUSH r24	;W E3 FFFF
	POP r24		;R E3 FFFF
	IN r10, SREG
	PUSH r10    ;W 14 FFFF
	POP r10     ;R 14 FFFF

;;;	test AND (Logical AND) ;;;
test_AND:
	LDI r25, $65	; r25 = b01100101
	LDI r26, $AC	; r26 = b10101100
	AND	r25, r26	; r25 = r25 AND r26 = b00100100
	PUSH r25     ;W 24 FFFF
	POP r25      ;R 24 FFFF
	IN r10, SREG 
	PUSH r10    ;W 00 FFFF
	POP r10     ;R 00 FFFF
	LDI r19, $67	; r19 = b01100111
	LDI r20,$01	; r20 = b00000001
	AND r19, r20	; r19 = r19 AND r20 = b00000001
	PUSH r19     ;W 01 FFFF
	POP r19      ;R 01 FFFF
	IN r10, SREG
	PUSH r10    ;W 00 FFFF
	POP r10     ;R 00 FFFF

;;; test ANDI (Logical AND with Immediate) ;;;
test_ANDI:
	LDI r25,	$4D	; r25 = b01001101
	ANDI r25, $63; r25 = r25 AND $63(b01100011) = b01000001
	PUSH r25     ;W 41 FFFF
	POP r25      ;R 41 FFFF
	IN r10, SREG ; load the status register. Flags should be 00000000
	PUSH r10    ;W 00 FFFF
	POP r10     ;R 00 FFFF
	ANDI r25, $00 ; r25 = r25 AND 0 = b00000000
	PUSH r25     ;W 00 FFFF
	POP r25      ;R 00 FFFF
	IN r10, SREG ; load the status register. Flags should be 00000010
	PUSH r10    ;W 02 FFFF
	POP r10     ;R 02 FFFF

;;; test ASR (Arithmetic Shift Right) ;;; 
; keep bit-7 and load bit-0 into Carry
test_ASR:
	BCLR 0		; C = 0
	LDI r16, $37	; r16 = b00110111 = 55
	ASR r16		; r16 = b00011011
	IN r10, SREG
	PUSH r10    ;W 19 FFFF
	POP r10     ;R 19 FFFF

;;; BCLR is already tested above ;;;

;;; test BLD(Bit load from T to register) ;;;
test_BLD:
	LDI r25, 0 ; r5 = 0
	BSET 6	  ; T = 1
	BLD	r25, 3 ; Load T flag into bit-3 of r5. r5 = 00001000
	PUSH r25  ;W 08 FFFF
	POP r25	  ;R 08 FFFF

;;; BSET is already tested above ;;;

;;; test BST(Bit store from register to T) ;;;
test_BST:
	BCLR 6		; T = 0
	LDI r17, $FF
	BST r17, 2    ; Store bit 2 of r17 in T
	IN r10, SREG
	PUSH r10    ;W 59 FFFF
	POP r10     ;R 59 FFFF
	LDI r17, $07
	BST r17, 3	; Store bit 3 of r7 in T
	IN r10, SREG
	PUSH r10    ;W 19 FFFF
	POP r10     ;R 19 FFFF

;;; test COM(One's complement) ;;;
test_COM:
	BCLR 0 ; Clear Carry
	LDI r20, $1E ; r20 = 00011110
	COM r20		 ; r20 = 11100001 (r10 = not r10)
	IN r10, SREG
	PUSH r10     ;W 03 FFFF
	POP r10      ;R 03 FFFF

;;; test CP(Compare) ;;;
test_CP:
	LDI r24, $F1 ; r24 = xF1
	LDI r25, $F1 ; r25 = xF1
	CP r24, r25   ; r24-r25 = x00, set Z flag
	IN r10, SREG ; load the status register. Flags should be 00000010
	PUSH r10    ;W 02 FFFF
	POP r10     ;R 02 FFFF
	LDI r24, $05 ; r4 = x05
	LDI r25, $0F	; r5 = x0F
	CP r24, r25   ; r4-r5 < 0
	IN r10, SREG
	PUSH r10    ;W 35 FFFF
	POP r10     ;R 35 FFFF

;;; test CPC(Compare with Carry) ;;;
test_CPC:
	LDI r24, $03
	LDI r25, $03
	BSET 0	     ; C = 1
	CPC r24, r25   ; r24 - r25 - C < 0
	PUSH r24	  ;W 03 FFFF
	POP r24       ;R 03 FFFF
	IN r10, SREG ; load the status register. Flags should be 00110101
	PUSH r10     ;W 35 FFFF
	POP r10      ;R 35 FFFF

;;; test CPI(Compare with Immediate) ;;;
test_CPI:
	LDI r23, $AF ; r3 = $AF
	CPI r23, $31 ; Compare r23 with $31. Do $AF-$31
	PUSH r23	 ;W AF FFFF
	POP r23      ;R AF FFFF
	IN r10, SREG ; load the status register. Flags should be 00011000
	PUSH r10    ;W 18 FFFF
	POP r10     ;R 18 FFFF
	LDI r23, $01 ; r23 = $01
	CPI r23, $01 ; Compare r23 with $03. Do $01-$01
	IN r10, SREG ; load the status register. Flags should be 00000010
	PUSH r10    ;W 02 FFFF
	POP r10     ;R 02 FFFF

;;; test DEC(Decrement) ;;;
test_DEC:
	LDI r22, $02 ; r22 = $02
	DEC r22      ; r22 = $02 - $01 = $01 (Decrement by 1)
	PUSH r22     ;W 01 FFFF
	POP r22      ;R 01 FFFF
	IN r10, SREG
	PUSH r10     ;W 00 FFFF
	POP r10      ;R 00 FFFF
	DEC r22 ; r22 = $01 - $01 = $00 (Decrement by 1)
	PUSH r22   ;W 00 FFFF
	POP r22    ;R 00 FFFF
	IN r10, SREG ; load status register. Flags should be ---00010
	PUSH r10   ;W 02 FFFF
	POP r10    ;R 02 FFFF

;;; test EOR(Exclusive OR) ;;;
test_EOR:
	LDI r20, $B3 ; r20 = 10110011
	LDI r21, $49 ; r21 = 01001001
	EOR r20, r21 ; r20 = r20 XOR r21 = 11111010
	IN r10, SREG
	PUSH r10 ;W 14 FFFF
	POP r10  ;R 14 FFFF

;;; test INC(Increment) ;;;
test_INC:
	LDI r23, $1A ; r23 = 00011010
	INC r23		 ; r23 = 00011011
	IN r10, SREG 
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	
;;; test LSR(Logical shift right) ;;;
test_LSR:
	BCLR 0 ; clear C flag
	LDI r23, $1F ; r23 = 00011111
	LSR r23      ; r23 = 00001111, C flag = 1
	IN r10, SREG ; load status register. Flags should be 00011001
	PUSH r10  ;W 19 FFFF
	POP r10   ;R 19 FFFF
	
;;; test NEG(Two's complement) ;;;
test_NEG:
	LDI r21, $23 ; r21 = b00100011
	NEG r21 ; take 2's complement of r21. r21 = $00 -$23 = $DD = b11011101 
	PUSH r21 ;W DD FFFF
	POP r21  ;R DD FFFF
	IN r10, SREG ; load status register. Flags should be 00110101
	PUSH r10 ;W 35 FFFF
	POP r10  ;R 35 FFFF

;;; test OR(Logical OR) ;;;
test_OR:
	LDI r21, $CF ; r21 = b11001111
	LDI r22, $1A ; r22 = b00011010
	OR r21, r22 ; r21 = r21 or r22 = b11011111
	PUSH r21 ;W DF FFFF
	POP r21  ;R DF FFFF
	IN r10, SREG ; load status register. Flags should be 00110101
	PUSH r10 ;W 35 FFFF
	POP r10  ;R 35 FFFF

;;; test ORI(Logical OR with immediate) ;;;
test_ORI:
	LDI r21, $A1 ; r21 = b10100001
	ORI r21, $3A ; r21 = b10100001 or b00111010 = b10111011
	PUSH r21 ;W BB FFFF
	POP r21  ;R BB FFFF
	IN r10, SREG ; load status register. Flags should be 00110101
	PUSH r10 ;W 35 FFFF
	POP r10  ;R 35 FFFF

;;; test ROR(Rotate right through carry) ;;;
test_ROR:
	BSET 0 ; set C flag
	LDI r21, $62 ; r21 = b01100010
	ROR r21 ; rotate r21 through carry. r21 = 10110001, C = 0
	PUSH r21 ;W B1 FFFF
	POP r21  ;R B1 FFFF
	IN r10, SREG ; load status register. Flags should be 00101100
	PUSH r10 ;W 2C FFFF
	POP r10  ;R 2C FFFF

;;; test SBC(Substract with carry) ;;;
test_SBC:
	BSET 0 ; set C flag
	LDI r21, $AB ; r21 = 10101011
	LDI r22, $30 ; r22 = 00110000
	SBC r21, r22 ; r21 = r21 - r22 - C = $AB - $30 - $01 = $7A
	PUSH r21  ;W 7A FFFF
	POP r21   ;R 7A FFFF
	IN r10, SREG ; load status register. Flags should be 00011000
	PUSH r10 ;W 18 FFFF
	POP r10  ;R 18 FFFF
	BCLR 0 ; clear C flag
	LDI r21, $CD ; r21 = 11001101
	LDI r22, $CD ; r22 = 11001101
	SBC r21, r22 ; r21 = r21 - r22 - C = $CD - $CD - $00 = $00
	PUSH r21  ;W 00 FFFF
	POP r21   ;R 00 FFFF
	IN r10, SREG ; load status register. Flags should be 00000010
	PUSH r10  ;W 02 FFFF
	POP r10   ;R 02 FFFF

;;; test SBCI(Substract immediate with carry) ;;;
test_SBCI:
	BSET 0 ; set C flag
	LDI r21, $BC ; r21 = 10111100
	SBCI r21, $40 ; r21 = $BC - $40 - $01 = $7B
	PUSH r21 ;W 7B FFFF
	POP r21  ;R 7B FFFF
	IN r10, SREG ; load status register. Flags should be 00011000
	PUSH r10 ;W 18 FFFF
	POP r10  ;R 18 FFFF
	BCLR 0 ; clear C flag
	LDI r21, $EF ; r21 = 11001101
	SBCI r21,$EF ; r21 = $EF - $EF - $00 = $00
	PUSH r21  ;W 00 FFFF
	POP r21   ;R 00 FFFF
	IN r10, SREG ; load status register. Flags should be 00000010
	PUSH r10 ;W 02 FFFF
	POP r10  ;R 02 FFFF

;;; test SBIW(Substract immediate from word) ;;;
; only works on upper four pairs of registers.
; the immediate value (K)'s size is 6 bits.
test_SBIW:
	LDI r25, $3F ; r25 = $DF
	LDI r24, $5A ; r24 = $5A
	SBIW r25:r24, $0C ; r25:r24 - K = $DF5A - $0C = $DF4E
	PUSH r24  ;W 4E FFFF
	POP r24   ;R 4E FFFF
	IN r10, SREG ; load status register. Flags should be 00000000
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	
;;; test SUB(Substract with carry) ;;;
test_SUB:
	LDI r23, $B3 ; r23 = $B3
	LDI r24, $12 ; r24 = $12
	SUB r23, r24  ; r23 = r23 - r24 = $A1
	PUSH r23 ;W A1 FFFF
	POP r23  ;R A1 FFFF
	IN r10, SREG ; load status register. Flgas should be 00010100
	PUSH r10 ;W 14 FFFF
	POP r10  ;R 14 FFFF

	LDI r23, $01 ; r23 = $01
	LDI r24, $0A ; r24 = $0A
	SUB r23, r24 ; r23 = r23 - r24 = $F7
	PUSH r23 ;W F7 FFFF
	POP r23  ;R F7 FFFF
	IN r10, SREG; load status register. Flags should be 00110101
	PUSH r10 ;W 35 FFFF
	POP r10  ;R 35 FFFF
	
;;; test SUBI(Substract immediate with carry) ;;;
test_SUBI:
	LDI r18, $CA
	SUBI r18, $A1 ; r18 = r18 - K = $CA - $A1 = $29
	PUSH r18 ;W 29 FFFF
	POP r18  ;R 29 FFFF
	IN r10, SREG ; load status register. Flags should be 00000000
	PUSH r10 ;W 00 FFFF
	POP r10  ;R 00 FFFF
	LDI r18, $80	
	SUBI r18, $40 ; r18 = r18 - K = $80 - $40 = $40
	PUSH r18 ;W 40 FFFF
	POP r18  ;R 40 FFFF
	IN r10, SREG ; load status register. Flags should be 00011000
	PUSH r10 ;W 18 FFFF
	POP r10  ;R 18 FFFF
	LDI r18, $1F 
	SUBI r18, $1F ; r18 = r18 - K = $00
	PUSH r18 ;W 00 FFFF
	POP r18  ;R 00 FFFF
	IN r10, SREG ; load status register. Flags should be 00000010
	PUSH r10 ;W 02 FFFF
	POP r10  ;R 02 FFFF

;;; test SWAP(Swap nibbles) ;;;
test_SWAP:
	LDI r25, $AD ; r25 = xAD
	SWAP r25 ; r25 = xDA
	PUSH r25 ;W DA FFFF
	POP r25  ;R DA FFFF

;;; test JMP(Jump) ;;;
test_JMP:
	JMP test_RJMP ; jump to test_RJMP
	LDI r20, $10

;;; test RJMP(Relative jump) ;;;
test_RJMP:
	RJMP test_IJMP ; relative jump to test_IJMP
	LDI r20, $10

;;; test IJMP(Indirect jump to [Z]) ;;;
test_IJMP:
	LDI r31, $01
	LDI r30, $D7 ; Set r31:r30 (Z register) = $01D7
	IJMP ; PC = Z(15:0) = $01D7. Jump to test_CALL(assuming test_CALL's PC is $01D7)
	LDI r20, $10
	
;;; test CALL(Call subroutine), RET(Subroutine return) ;;;
test_CALL:
	LDI r21, $00 ; r21 = $00
	CALL CALL_check ; go to CALL_check. unconditional branch
	JMP test_RCALL ; after returning from subroutine, jump to the next test
CALL_check:
	LDI r21, $01
	RET

;;; test RCALL(Relative call subroutine), RET(Subroutine return) ;;;
test_RCALL:
	LDI r21, $00
	RCALL RCALL_subroutine ; go to subroutine
	JMP test_ICALL ; after returning from subroutine, jump to the next test
RCALL_subroutine:
	LDI r21, $01
	RET

;;; test ICALL(Indirect call to [z]), RET(Subroutine return) ;;;
test_ICALL:
	LDI r31, $01
	LDI r30, $E9
	ICALL ; PC = Z(15:0) = $01E9. go to ICALL_subroutine(assuming its PC is $01E9)
	JMP test_RETI ; after returning from subroutine, jump to next test
ICALL_subroutine:
	LDI r21, $FF
	RET

;;; test RETI(Interrupt return) ;;;
test_RETI:
	BCLR 7	; clear I flag
	CALL RETI_check ; call the subroutine
	IN r10, SREG ; load status register to check I flag
	PUSH r10 ;W 82 FFFF
	POP r10  ;R 82 FFFF
	JMP test_CPSE ; go to next test
RETI_check:
	RETI ; return and set I flag

;;; BRBC and BRBS are already tested above ;;;

;;; test CPSE(Compare, skip if equal) ;;;
test_CPSE:
	LDI r23, $10
	LDI r24, $10
	CPSE r23, r24 ; Since r23 = r24, skip JMP
	JMP test_CPSE
	CPSE r23, r24 ; Since r23 != r24, don't skip
	LDI r20, $CC

;;; test SBRC(Skip if bit in register cleared) ;;;
test_SBRC:
	LDI r20, $10 ; r20 = b00010000, bit-4 = '1'
	SBRC r20, 4 ; should not skip since bit-4 of r20 is not cleared
	LDI r20, $55
	SBRC r20, 3 ; should skip since bit-3 of r20 is cleared
	JMP test_SBRC
	LDI r20, $00 ; r20 = b00000000, bit-4 = '0'
	SBRC r20, 4 ; should skip NOP since bit-4 of r20 is now cleared
	JMP test_SBRC

;;; test SBRS(Skip if bit in register set) ;;;
test_SBRS:
	LDI r21, $FF ; r21 = b11111111
	SBRS r21, 3 ; should skip NOP since bit-3 is set
	JMP test_SBRS
	LDI r21, $F7 ; r21 = b11110111
	SBRS r21, 3 ; should not skip NOP since bit-3 is not set
	LDI r21, $FF

;;; All tests over ;;;
; Clear all flags (Not Necessary)
test_OVER:
	BCLR 0
	BCLR 1
	BCLR 2
	BCLR 3
	BCLR 4
	BCLR 5
	BCLR 6
	BCLR 7
