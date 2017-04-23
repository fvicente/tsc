;-------------------------------------------------------------------------;
;                                TSC 1.0                                  ;
;               January '08  AlferSoft (fvicente@gmail.com)               ;
;                                                                         ;
;                                                                         ;
;  RA0, RA1, RA2 to CD4021 serial input PIN 3 (Q8), 10 (CLK), 9 (P/S)     ;
;  RA3, RB6, RB7 to CD4094 serial output PIN 1 (STR), 3 (CLK), 2 (D)      ;
;  RB0, RB1, RB2 to L293D motor driver PIN 7 (2A), 2 (1A), 1 (1,2EN)      ;
;  RB3, RB4, RB5 to L293D motor driver PIN 15 (4A), 10 (3A), 9 (3,4EN)    ;
;-------------------------------------------------------------------------;

    ERRORLEVEL -302 ; remove message about using proper bank

    LIST p=16F628A
    #INCLUDE "p16f628a.inc"

    __CONFIG _INTOSC_OSC_NOCLKOUT & _BOREN_ON & _CP_ON & _DATA_CP_OFF & _PWRTE_ON & _WDT_ON & _LVP_OFF & _MCLRE_ON

;-------------------------------------------------------------------------;
;    Here we define our own personal registers and give them names        ;
;-------------------------------------------------------------------------;

    CBLOCK 0x20
        INPUT                  ; this register holds input bits
        PRESSED                ; B'00000000' nothing pressed
                               ; B'10000000' gear up pressed
                               ; B'01000000' gear down pressed
                               ; B'11000000' both gear up and down pressed
        BOUNCECNT              ; button bounce counter
        TMPCNT                 ; temporary counter
        CNTMSEC                ; used in timing of milliseconds
        CURSTATE               ; current sensor state
        TMPVAR                 ; temporary variable
        ERRFLG                 ; bit 0 only, tells if an error has occurred
        TOCNT                  ; gear timeout counter
    ENDC

;-------------------------------------------------------------------------;
;                                 Inputs                                  ;
;-------------------------------------------------------------------------;

#DEFINE   CD4021_Q8		PORTA,0		; serial input data

;-------------------------------------------------------------------------;
;                                Outputs                                  ;
;-------------------------------------------------------------------------;

#DEFINE   CD4021_CLK	PORTA,1		; serial input clock
#DEFINE   CD4021_LATCH	PORTA,2		; serial input p/s control (latch)
#DEFINE   CD4094_STR	PORTA,3		; serial output strobe
#DEFINE   CD4094_CLK	PORTB,6		; serial output clock
#DEFINE   CD4094_DATA	PORTB,7		; serial output data
#DEFINE   L293_2A		PORTB,0		; motor driver 2A
#DEFINE   L293_1A		PORTB,1		; motor driver 1A
#DEFINE   L293_12EN		PORTB,2		; motor driver 12EN
#DEFINE   L293_4A		PORTB,3		; motor driver 4A
#DEFINE   L293_3A		PORTB,4		; motor driver 3A
#DEFINE   L293_34EN		PORTB,5		; motor driver 34EN

;-------------------------------------------------------------------------;
;    Here we give names to some numbers to make their use more clear      ;
;-------------------------------------------------------------------------;

#DEFINE   GEAR_UP       D'7'           ; gear up
#DEFINE   GEAR_DOWN     D'6'           ; gear down

#DEFINE   STATE_ALL     B'00111111'    ; possible states
#DEFINE   STATE_N       B'00101101'    ; state N
#DEFINE   STATE_1       B'00011101'    ; state 1
#DEFINE   STATE_2       B'00110101'    ; state 2
#DEFINE   STATE_3       B'00101011'    ; state 3
#DEFINE   STATE_4       B'00101110'    ; state 4

;-------------------------------------------------------------------------;
;         We set the start of code to orginate a location zero            ;
;-------------------------------------------------------------------------;

      ORG 0x00
      GOTO MAIN                        ; jump to the main routine
                     
      ORG 0x04
      RETFIE                           ; no interrupt routine

;-------------------------------------------------------------------------;
;                             Gear up and down                            ;
;-------------------------------------------------------------------------;
; EN 1A 2A FUNCTION                                                       ;
; H  L  H  Turn right                                                     ;
; H  H  L  Turn left                                                      ;
; H  L  L  Fast motor stop                                                ;
; H  H  H  Fast motor stop                                                ;
; L  X  X  Fast motor stop                                                ;
;-------------------------------------------------------------------------;

GET_STATE   MOVF INPUT,W               ; copy input to W
            ANDLW STATE_ALL            ; leave only states bits
			MOVWF CURSTATE             ; copy W into CURSTATE
            XORLW STATE_N              ; see if current state is N
			BTFSC STATUS,Z             ; skip result is different to 0
			RETLW D'0'
			MOVF CURSTATE,W            ; copy current state into W
            XORLW STATE_1              ; see if current state is 1
			BTFSC STATUS,Z             ; skip result is different to 0
			RETLW D'1'
			MOVF CURSTATE,W            ; copy current state into W
            XORLW STATE_2              ; see if current state is 2
			BTFSC STATUS,Z             ; skip result is different to 0
			RETLW D'2'
			MOVF CURSTATE,W            ; copy current state into W
            XORLW STATE_3              ; see if current state is 3
			BTFSC STATUS,Z             ; skip result is different to 0
			RETLW D'3'
			MOVF CURSTATE,W            ; copy current state into W
            XORLW STATE_4              ; see if current state is 3
			BTFSC STATUS,Z             ; skip result is different to 0
			RETLW D'4'
			RETLW D'5'                 ; unknown state

DO_GEAR_UP  CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO FROM_N_TO_1
			GOTO FROM_1_TO_2
			GOTO FROM_2_TO_3
			GOTO FROM_3_TO_4
			GOTO AFTER_GEAR
			GOTO UNK_STATE             ; unknown state

DO_GEAR_DN  CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO AFTER_GEAR
			GOTO FROM_1_TO_N
			GOTO FROM_2_TO_1
			GOTO FROM_3_TO_2
			GOTO FROM_4_TO_3
			GOTO UNK_STATE             ; unknown state

STOP_MT_1   BCF L293_12EN
            BCF L293_2A
            BCF L293_1A
			RETURN

STOP_MT_1_D CALL STOP_MT_1
            CALL DRAW_LEDS
			GOTO AFTER_GEAR

MT_1_RIGHT  BSF L293_2A
            BCF L293_1A
			BSF L293_12EN
			RETURN

MT_1_LEFT   BCF L293_2A
            BSF L293_1A
			BSF L293_12EN
			RETURN

STOP_MT_2   BCF L293_34EN
            BCF L293_4A
            BCF L293_3A
			RETURN

STOP_MT_2_D CALL STOP_MT_2
            CALL DRAW_LEDS
			GOTO AFTER_GEAR

MT_2_RIGHT  BSF L293_4A
            BCF L293_3A
			BSF L293_34EN
			RETURN

MT_2_LEFT   BCF L293_4A
            BSF L293_3A
			BSF L293_34EN
			RETURN

FROM_N_TO_1 CALL MT_1_LEFT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_N_TO_1 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT1_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOOP_N_TO_1
			GOTO STOP_MT_1_D
			GOTO LOOP_N_TO_1
			GOTO LOOP_N_TO_1
			GOTO LOOP_N_TO_1
			GOTO LOOP_N_TO_1           ; unknown state may be correct during gear transition

FROM_1_TO_2 CALL MT_1_RIGHT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_1_TO_2 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT1_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOOP_1_TO_2
			GOTO LOOP_1_TO_2
			GOTO STOP_MT_1_D
			GOTO LOOP_1_TO_2
			GOTO LOOP_1_TO_2
			GOTO LOOP_1_TO_2           ; unknown state may be correct during gear transition

FROM_2_TO_3 CALL MT_1_LEFT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_2_TO_3 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT1_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO CONT_2_TO_3
			GOTO LOOP_2_TO_3
			GOTO LOOP_2_TO_3
			GOTO LOOP_2_TO_3
			GOTO LOOP_2_TO_3
			GOTO LOOP_2_TO_3           ; unknown state may be correct during gear transition
CONT_2_TO_3 CALL STOP_MT_1
            CALL MT_2_LEFT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOO2_2_TO_3 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT2_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOO2_2_TO_3
			GOTO LOO2_2_TO_3
			GOTO LOO2_2_TO_3
			GOTO STOP_MT_2_D
			GOTO LOO2_2_TO_3
			GOTO LOO2_2_TO_3           ; unknown state may be correct during gear transition

FROM_3_TO_4 CALL MT_2_RIGHT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_3_TO_4 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT2_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOOP_3_TO_4
			GOTO LOOP_3_TO_4
			GOTO LOOP_3_TO_4
			GOTO LOOP_3_TO_4
			GOTO STOP_MT_2_D
			GOTO LOOP_3_TO_4           ; unknown state may be correct during gear transition

FROM_1_TO_N CALL MT_1_RIGHT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_1_TO_N CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT1_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO STOP_MT_1_D
			GOTO LOOP_1_TO_N
			GOTO LOOP_1_TO_N
			GOTO LOOP_1_TO_N
			GOTO LOOP_1_TO_N
			GOTO LOOP_1_TO_N           ; unknown state may be correct during gear transition

FROM_2_TO_1 CALL MT_1_LEFT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_2_TO_1 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT1_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOOP_2_TO_1
			GOTO STOP_MT_1_D
			GOTO LOOP_2_TO_1
			GOTO LOOP_2_TO_1
			GOTO LOOP_2_TO_1
			GOTO LOOP_2_TO_1           ; unknown state may be correct during gear transition

FROM_3_TO_2 CALL MT_2_RIGHT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_3_TO_2 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT2_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO CONT_3_TO_2
			GOTO LOOP_3_TO_2
			GOTO LOOP_3_TO_2
			GOTO LOOP_3_TO_2
			GOTO LOOP_3_TO_2
			GOTO LOOP_3_TO_2           ; unknown state may be correct during gear transition
CONT_3_TO_2 CALL STOP_MT_2
            CALL MT_1_RIGHT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOO2_3_TO_2 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT1_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOO2_3_TO_2
			GOTO LOO2_3_TO_2
			GOTO STOP_MT_1_D
			GOTO LOO2_3_TO_2
			GOTO LOO2_3_TO_2
			GOTO LOO2_3_TO_2           ; unknown state may be correct during gear transition

FROM_4_TO_3 CALL MT_2_LEFT
            MOVLW D'100'               ; timeout to 2 seconds (100 delays of 20ms)
			MOVWF TOCNT
            GOTO $+2                   ; skip first delay
LOOP_4_TO_3 CALL ONEMSEC
            DECFSZ TOCNT,f             ; finished count down
            GOTO $+2
            GOTO MT2_TIMEOUT           ; timeout reached
            CALL READ_INPUT            ; read serial input
			CALL GET_STATE             ; state offset is stored in W
            ADDWF PCL,f
			GOTO LOOP_4_TO_3
			GOTO LOOP_4_TO_3
			GOTO LOOP_4_TO_3
			GOTO STOP_MT_2_D
			GOTO LOOP_4_TO_3
			GOTO LOOP_4_TO_3           ; unknown state may be correct during gear transition

MT1_TIMEOUT CALL STOP_MT_1
            GOTO UNK_STATE

MT2_TIMEOUT CALL STOP_MT_2
            GOTO UNK_STATE

UNK_STATE   BSF ERRFLG,0
            CALL DRAW_LEDS
			GOTO AFTER_GEAR

DRAW_LEDS	CLRF TMPVAR                ; into temporary variable
            CALL GET_STATE             ; state offset is stored in W
            MOVWF TMPCNT               ; into counting register
            INCF TMPCNT,1
            BSF STATUS,C
ROTATE      RLF TMPVAR,1
            DECFSZ TMPCNT,f
            GOTO ROTATE
			BTFSC ERRFLG,0
			BSF TMPVAR,5
			MOVLW D'8'                 ; 8
			MOVWF TMPCNT               ; into counting register
            BCF STATUS,C
LOOPBITW	RRF TMPVAR,W
            BTFSS STATUS,C
			GOTO CONTOFFW
			GOTO CONTONW
CONTONW     BSF CD4094_DATA            ; set data
			GOTO CONTINUEW
CONTOFFW    BCF CD4094_DATA            ; clear data
CONTINUEW   MOVWF TMPVAR               ; into temporary variable
			BSF CD4094_CLK             ; set clock
            CALL ONEMSEC
			BCF CD4094_CLK             ; clear clock
            CALL ONEMSEC
            DECFSZ TMPCNT,f            ; finished count down
            GOTO LOOPBITW              ; continue write loop
			BSF CD4094_STR             ; set strobe
            CALL ONEMSEC
			BCF CD4094_STR             ; clear strobe
			NOP
            RETURN

;-------------------------------------------------------------------------;
;                               Read inputs                               ;
;-------------------------------------------------------------------------;

READ_INPUT  CLRF INPUT
            BSF CD4021_LATCH           ; latch high
            CALL ONEMSEC
			BCF CD4021_LATCH           ; latch low
            NOP
			NOP
			MOVLW D'8'                 ; 8
			MOVWF TMPCNT               ; into counting register
            BCF CD4021_CLK             ; clear clock
LOOPBITR    BCF STATUS,C               ; clear C bit
            BTFSC CD4021_Q8            ; skip bit is not set
            BSF STATUS,C               ; if it is set bit 7 of temp
            RLF INPUT,F                ; shift right
            BSF CD4021_CLK             ; set clock
            CALL ONEMSEC
            BCF CD4021_CLK             ; clear clock
            CALL ONEMSEC
            DECFSZ TMPCNT,1            ; see if 8 bits have been read
            GOTO LOOPBITR
            RETURN

;-------------------------------------------------------------------------;
;  1 millisecond delay routine                                            ;  
;-------------------------------------------------------------------------;

ONEMSEC     MOVLW .249                 ; 1 microsec for load W
                                       ; loops below take 248 X 4 + 3 = 995
MICRO4      ADDLW H'FF'                ; subtract 1 from 'W'
            CLRWDT                     ; clear watch dog timer
            BTFSS STATUS,Z             ; skip when you reach zero
            GOTO MICRO4                ; loops takes 4 microsec, 3 for last
            RETURN                     ; takes 2 microsec
                                       ; call + load  W + loops + return =
                                       ; 2 + 1 + 995 + 2 = 1000 microsec

;-------------------------------------------------------------------------;
;          Initialization routine sets up ports and timer                 ;
;-------------------------------------------------------------------------;

INIT        BCF STATUS,RP1
			BSF STATUS,RP0				; set bank 1
			MOVLW B'00000001'			; RA0 input, the rest outputs
			MOVWF TRISA
			MOVLW B'00000000'			; all bits of PORTB as outputs
			MOVWF TRISB
			MOVLW B'10000000'			; disable pull-up resistors <7>
			MOVWF OPTION_REG
            MOVLW B'00000000'
            MOVWF INTCON                ; disable device interruption
			BCF STATUS,RP1
			BCF STATUS,RP0				; set bank 0
			MOVLW B'00000111'			; set bits RA3:RA0 as I/O <2:0>
			MOVWF CMCON
            ; init variables
			CLRF ERRFLG
            RETURN                     

;-------------------------------------------------------------------------;
;            This is the main routine, the program starts here            ;
;-------------------------------------------------------------------------;

MAIN        CALL INIT                  ; set up ports etc.
MAIN_LOOP   CALL ONEMSEC
            CALL READ_INPUT            ; read serial input
            CALL DRAW_LEDS
            CLRF PRESSED               ; clear pressed flag
			BTFSS INPUT,GEAR_UP        ; skip if gear up bit is high (not pressed)
			GOTO WAIT_BUTUP
            BTFSS INPUT,GEAR_DOWN      ; skip if gear down bit is high (not pressed)
			GOTO WAIT_BUTUP
			GOTO MAIN_LOOP
CLICKED     MOVF PRESSED,W             ; copy input to W
            ANDLW B'11000000'          ; leave only gear button bits
            XORLW B'11000000'          ; xor result
			BTFSC STATUS,Z             ; skip result is different to 0
            GOTO MAIN_LOOP             ; two bits are on, command cancelled
            BTFSC PRESSED,GEAR_UP      ; skip if gear up is not pressed
            GOTO DO_GEAR_UP
            BTFSC PRESSED,GEAR_DOWN    ; skip if gear down is not pressed
            GOTO DO_GEAR_DN
AFTER_GEAR  GOTO MAIN_LOOP             ; continue waiting for an event

;-------------------------------------------------------------------------;
;      Wait for gear up/down buttons to be released handling bounce       ;
;-------------------------------------------------------------------------;

WAIT_BUTUP  MOVF INPUT,W               ; copy input to W
            XORLW 0xFF                 ; invert bits on W
			ANDLW B'11000000'          ; leave only gear button bits
			IORWF PRESSED,1            ; or W with pressed register and store result on it
            MOVLW 0FFH                 ; set accumulator to 0FFh
            MOVWF BOUNCECNT            ; move accumulator content to bounce counter
BOUNCE      DECFSZ BOUNCECNT,f
            GOTO BOUNCE                ; loop until counter is 0
WAIT_REL    CALL READ_INPUT            ; read serial input
            MOVF INPUT,W               ; copy input to W
            XORLW 0xFF                 ; invert bits on W
			ANDLW B'11000000'          ; leave only gear button bits
			IORWF PRESSED,1            ; or W with pressed register and store result on it
			BTFSS INPUT,GEAR_UP        ; skip if gear up is not pressed
            GOTO WAIT_REL              ; wait for button release
			BTFSS INPUT,GEAR_DOWN      ; skip if gear down is not pressed
			GOTO WAIT_REL              ; wait for button release
            GOTO CLICKED               ; continue execution of main loop

    END
