		TTL Exercise 07 Circular FIFO Queue Operations
		
;****************************************************************
;Date:  10/01/2015
;Class:  CMPE-250
;Section:  03 TR 2-4PM
;---------------------------------------------------------------
;Keil Template for KL46
;R. W. Melton
;April 3, 2015
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL46Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates

;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port A
PORT_PCR_SET_PTA1_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTA2_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select
;         (PLLFLLSEL determines MCGFLLCLK' or MCGPLLCLK/2)
; 1=   16:PLLFLLSEL=PLL/FLL clock select (MCGPLLCLK/2)
SIM_SOPT2_UART0SRC_MCGPLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
SIM_SOPT2_UART0_MCGPLLCLK_DIV2 EQU \
    (SIM_SOPT2_UART0SRC_MCGPLLCLK :OR: SIM_SOPT2_PLLFLLSEL_MASK)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;26->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R    EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
UART0_C2_T_RI   EQU  (UART0_C2_RIE_MASK :OR: UART0_C2_T_R)
UART0_C2_TI_RI  EQU  (UART0_C2_TIE_MASK :OR: UART0_C2_T_RI)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  0x1F
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  0xC0
;---------------------------------------------------------------
;---------------------------------------------------------------
;NVIC_ICER
;31-00:CLRENA=masks for HW IRQ sources;
;             read:   0 = unmasked;   1 = masked
;             write:  0 = no effect;  1 = mask
;22:PIT IRQ mask
;12:UART0 IRQ mask
NVIC_ICER_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ICER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_ICPR
;31-00:CLRPEND=pending status for HW IRQ sources;
;             read:   0 = not pending;  1 = pending
;             write:  0 = no effect;
;                     1 = change status to not pending
;22:PIT IRQ pending status
;12:UART0 IRQ pending status
NVIC_ICPR_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ICPR_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_IPR0-NVIC_IPR7
;2-bit priority:  00 = highest; 11 = lowest
;--PIT
PIT_IRQ_PRIORITY    EQU  0
NVIC_IPR_PIT_MASK   EQU  (3 << PIT_PRI_POS)
NVIC_IPR_PIT_PRI_0  EQU  (PIT_IRQ_PRIORITY << UART0_PRI_POS)
;--UART0
UART0_IRQ_PRIORITY    EQU  3
NVIC_IPR_UART0_MASK   EQU  (3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI_3  EQU  (UART0_IRQ_PRIORITY << UART0_PRI_POS)
;---------------------------------------------------------------
;NVIC_ISER
;31-00:SETENA=masks for HW IRQ sources;
;             read:   0 = masked;     1 = unmasked
;             write:  0 = no effect;  1 = unmask
;22:PIT IRQ mask
;12:UART0 IRQ mask
NVIC_ISER_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ISER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;PIT_LDVALn:  PIT load value register n
;31-00:TSV=timer start value (period in clock cycles - 1)
;Clock ticks for 0.01 s at 24 MHz count rate
;0.01 s * 24,000,000 Hz = 240,000
;TSV = 240,000 - 1
PIT_LDVAL_10ms  EQU  239999
;---------------------------------------------------------------
;PIT_MCR:  PIT module control register
;1-->    0:FRZ=freeze (continue'/stop in debug mode)
;0-->    1:MDIS=module disable (PIT section)
;               RTI timer not affected
;               must be enabled before any other PIT setup
PIT_MCR_EN_FRZ  EQU  PIT_MCR_FRZ_MASK
;---------------------------------------------------------------
;PIT_TCTRLn:  PIT timer control register n
;0-->   2:CHN=chain mode (enable)
;1-->   1:TIE=timer interrupt enable
;1-->   0:TEN=timer enable
PIT_TCTRL_CH_IE  EQU  (PIT_TCTRL_TEN_MASK :OR: PIT_TCTRL_TIE_MASK)
;---------------------------------------------------------------
;Interrupt should be set to the highest priority
PIT_IRQ_PRI 	 EQU 0
;---------------------------------------------------

;Max length of queue
Q_BUF_SZ				EQU 4
Q_REC_SZ                EQU 18

;Max length of prompt string
MAX_STRING 				EQU 79
	
IN_PTR					EQU 0
OUT_PTR					EQU 4
BUF_START				EQU 8
BUF_PAST				EQU 12
BUF_SIZE				EQU 16
NUM_ENQD				EQU 17
	
FiveSec			EQU	 50

;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
Reset_Handler
main
			
;---------------------------------------------------------------
;KL46 system startup with 48-MHz system clock
			CPSID I

            BL      Startup
			
			;Enable clock interrupts
			BL      Init_UART0_IRQ
			BL 		Init_PIT_IRQ

PRINT_PROMPT
			;Initalize RunStopwatch and Count to 0
			LDR R0, =RunStopWatch
			MOVS R1, #0
			STRB R1, [R0, #0]
			
			LDR R0, =Count
			MOVS R1, #0
			STR R1, [R0, #0]
			
			;Print out the initial prompt
			LDR R0, =AccessCodePrompt
			BL PutStringSB
			
			;Print CR and LF to the screen
			MOVS R0, #0x0D
			BL PutChar
			
			MOVS R0, #0x0A
			BL PutChar
			
			MOVS R0, #">"
			BL PutChar
			
			;Initalize RunStopwatch to 1 and Count to 0
			LDR R0, =Count
			MOVS R1, #0
			STR R1, [R0, #0]
			
			LDR R0, =RunStopWatch
			MOVS R1, #1
			STRB R1, [R0, #0]
			
			;Accept string of user input for the code
			MOVS R1, #MAX_STRING
			LDR R0, =InputString
			BL GetStringSB
			
			;Set RunStopWatch to 0
			LDR R0, =RunStopWatch
			MOVS R1, #0
			STRB R1, [R0, #0]
			
			;Print CR and LF to the screen
			MOVS R0, #0x0D
			BL PutChar
			
			MOVS R0, #0x0A
			BL PutChar
			
			MOVS R0, #'<'
			BL PutChar
			
			;Print the value of count once the access code is entered
			LDR R0, =Count
			LDR R0, [R0, #0]
			MOVS R1, R0
			
			;Print value of count followed by ' x .01 s'
			BL PutNumU
			
			LDR R0, =TimeString
			BL PutStringSB
			
			;Print CR and LF to the screen
			MOVS R0, #0x0D
			BL PutChar
			
			MOVS R0, #0x0A
			BL PutChar
			
			;Divide count value by 10 for accurate comparisons
			MOVS R0, #10
			
			BL DIVU
			
			CMP R0, #FiveSec
			BGE MISSION_FAILURE
			
			LDR R0, =InputString
			LDR R1, =SecretCode
			
			;Length of the secret code
			MOVS R2, #7
			
CHECK_CHAR
			LDRB R3, [R0, R2]
			LDRB R4, [R1, R2]
			
			CMP R3, R4
			
			;If access code equals 25015110, access is granted
			BNE MISSION_FAILURE
			
			;If we have processed all characters without failure, the string matches
			CMP R2, #0
			BEQ MISSION_COMPLETE
			
			;Continue checking characters
			SUBS R2, R2, #1
			B CHECK_CHAR
			

MISSION_COMPLETE
			LDR R0, =Granted
			BL PutStringSB
			
			MOVS R0, #0x0D
			BL PutChar
			
			MOVS R0, #0x0A
			BL PutChar
			
			LDR R0, =Complete
			BL PutStringSB
			
			;Print CR and LF to the screen
			MOVS R0, #0x0D
			BL PutChar
			
			MOVS R0, #0x0A
			BL PutChar
			
			B PRINT_PROMPT
			
MISSION_FAILURE
			LDR R0, =Denied
			BL PutStringSB
			
			MOVS R0, #0x0D
			BL PutChar
			
			MOVS R0, #0x0A
			BL PutChar
			
			B PRINT_PROMPT
;>>>>>   end main program code <<<<<
;Stay here
END_PROGRAM
            B       .
	    
	    ;Increase memory to store code segments?
	    LTORG
;>>>>> begin subroutine code <<<<<

;-------------------------------------------
PutNumUB
;PutNumUB: Print the least significant unsigned 
;byte value from R0 to the screen. 

;Inputs:
	;R0 = value to print to the terminal screen in UB form
;Outputs
	;N/A
;-------------------------------------------
			PUSH {R1, LR}
			MOVS R1, #0xFF
			
			;Mask off everything but the last byte
			ANDS R0, R0, R1
			
			BL PutNumU
			
			POP {R1, PC}

;-------------------------------------------
;PIT_ISR
;Timer Interrupt Service Routine

;On a PIT interrupt, if the variable RunStopWatch
;is not equal to zero, the word variable Count is incremented
;Otherwise, the count variable is unchanged.

;The ISR then clears the interrupt condition and returns
;-----------------------------------------
PIT_ISR
			
			LDR R0, =RunStopWatch
			LDRB R0, [R0, #0]
			
			CMP R0, #0
			BNE INCR_COUNT
			B END_PIT_ISR
			
INCR_COUNT
			;Add #1 to count if stopwatch is running
			LDR R0, =Count
			LDR R1, [R0, #0]
			ADDS R1, R1, #1
			STR R1, [R0, #0]

END_PIT_ISR
			;Clear interrupt condition
			LDR R0, =PIT_CH0_BASE
			LDR R1, =PIT_TFLG_TIF_MASK
			
			STR R1, [R0, #PIT_TFLG_OFFSET]
			
			BX LR

;-------------------------------------------
;UART0_ISR
;Interrupt service routine for UART0 
;Check status of interrupt that triggered the ISR
;And react appropriately. If transmit interrupt enabled,
;write to UART0 transmit data register. If rx enabled
;enqueue to transmit queue from UART0 recieve data register
;-----------------------------------------
UART0_ISR
			
			;Mask other interrupts
			CPSID I
			;Pust relevant registers on to the stack
			PUSH {LR, R0-R3}
			
			LDR R0, =UART0_BASE
			
			;If txinterrupt enabled (UART0_C2 Bit 7 is set)
			LDRB R1,[R0,#UART0_C2_OFFSET]
			MOVS R2, #0x80
			
			ANDS R1, R1, R2
			
			CMP R1, #0
			BNE TX_ENABLED
			
			;If no TxInterrupt, check for Rx
			B CHECK_RX_INT
			
TX_ENABLED
			
			LDRB R1,[R0,#UART0_S1_OFFSET]
			MOVS R2, #0x80
			
			ANDS R1, R1, R2
			CMP R1, #0
			BEQ CHECK_RX_INT
			
			;Dequeue character
			;Load input params to initalize queue structure
			LDR R1, =TxQueueRecord
			MOVS R2, #Q_BUF_SZ
			
			BL DeQueue
			
			;Dequeue was unsuccessful
			BCS DISABLE_TX
			
			;Dequeue was successful
			LDR R1, =UART0_BASE
			
			;Transmit Character Stored in R0
			STRB R0, [R1, #UART0_D_OFFSET]
			
			B END_ISR
			
DISABLE_TX
			;UART0 <- C2_T_RI
			MOVS R1,#UART0_C2_T_RI
            STRB R1,[R0,#UART0_C2_OFFSET]
			
			;Pop values and return
			B END_ISR
			
CHECK_RX_INT
			LDR R0, =UART0_BASE
			
			;Check if an RxInterrupt exists
			LDRB R1,[R0,#UART0_S1_OFFSET]
			MOVS R2, #0x10
			
			ANDS R1, R1, R2
			CMP R1, #0
			BEQ END_ISR
			
			;Receive character and store in R0
			LDR R0, =UART0_BASE
			LDRB R3, [R0, #UART0_D_OFFSET]
			
			;Enqueue character with character stored in R0
			;Load input params to initalize queue structure
			LDR R1, =RxQueueRecord
			MOVS R0, R3
			
			BL EnQueue
			
			;No need to check return of EnQueue
			;character will be lost if the queue is full!

END_ISR
			;pop relevant registers off the stack
			
			;Unmask other interrupts
			CPSIE I
			
			;Return back to our business
			POP {R0-R3, PC}

PutNumHex
;PutNumHex: Print hex representation of a value
;To the console. Separates each nibble via masking
;And then converts to appropriate ASCII representation
;Inputs:
    ;R0 - Value to print to the screen
;Outputs: N/A
;--------------------------------------------
        PUSH {R2, R3, R4, LR}
    
        MOVS R2, #32

HEX_PRINT_LOOP

        ;Iterate 8 times for each digit stored in a register
        CMP R2, #0
        BLT END_PRINT_HEX
        
        ;Shift current nibble to print to
        ;the rightmost value of register
        MOVS R3, R0
		MOVS R4, #0x0F
		LSRS R3, R2
		
		ANDS R4, R4, R3
		
        ;Convert to appropriate ASCII value
        CMP R4, #10
        BGE PRINT_LETTER
        
        ;If 0-9 should be printed, add ASCII '0' val
        ADDS R4, #'0'
        B PRINT_HX
        
PRINT_LETTER
        
        ;If A-F should be printed, Add ASCII '55'
        ;To convert to capital letter value
        ADDS R4, R4, #55
        
PRINT_HX
        ;Print ASCII value to the screen
        ;Make sure not to destroy vlue in R0!
        PUSH {R0}
        MOVS R0, R4
        BL PutChar
        POP {R0}
        
        ;Reset value in R3 and increment loop counter
        MOVS R4, #0
        SUBS R2, R2, #4
        B HEX_PRINT_LOOP
        
END_PRINT_HEX
       
        POP {R2, R3, R4, PC}
;--------------------------------------------

InitQueue
;InitQueue: Initalize Circular FIFO Queue Structure
;Inputs:
    ;R0 - Memory location of queue buffer
    ;R1 - Address to place Queue record structure
    ;R2 - Size of queue structure (character capacity)
;Outputs: N/A
;--------------------------------------------

		;Store memory address of front of queue
		;Into IN_PTR position of the buffer
		STR R0, [R1, #IN_PTR]

		;Store same memory address for OUT_PTR
		;position in the buffer since queue is empty
		STR R0, [R1, #OUT_PTR]

		;Store same memory address in BUF_START for initalization
		STR R0, [R1, #BUF_START]

		;Store BUF_PAST in last slot of buffer
        ADDS R0, R0, R2
		STR R0, [R1, #BUF_PAST]

		;Store BUF_SIZE with size in R2
		STR R2, [R1, #BUF_SIZE]
		
		;Initalize NUM_ENQD to zero and 
		;store in 6th slot of buffer
		MOVS R0, #0
		STRB R0, [R1, #NUM_ENQD]
		
		BX	LR

;--------------------------------------------

DeQueue
;DeQueue: Remove an element from the circular FIFO Queue
;Inputs:
	;R1 - Address of Queue record structure
;Outputs:
	;R0 - Character that has been dequeued
	;PSR C flag (failure if C = 1, C = 0 otherwise.)
;--------------------------------------------
			PUSH {R1, R2, R3, R4}
			
			;If the number enqueued is 0, 
			;Set failure PSR flag
			LDRB R3, [R1, #NUM_ENQD]
			CMP R3, #0
			BLE DEQUEUE_FAILURE
			
			;Remove the item from the queue
			;And place in R0
			LDR R0, [R1, #OUT_PTR]
			
			;Load actual queue value into R0
			LDRB R0, [R0, #0]
			
			;Decrement number of enqueued elements
			;And store info back in buffer
			LDRB R3, [R1, #NUM_ENQD]
			SUBS R3, R3, #1
			STRB R3, [R1, #NUM_ENQD] 
			
			;Increment location of out_pointer
			LDR R3, [R1, #OUT_PTR]
			ADDS R3, R3, #1
			STR R3, [R1, #OUT_PTR] 
			
			;Compare OUT_PTR to BUF_PAST
			;If out_ptr >= BUF_PAST, wrap the queue around
			LDR R4, [R1, #BUF_PAST]
			CMP R3, R4
			BGE WRAP_BUFFER
			B DEQUEUE_CLEAR_PSR
			
WRAP_BUFFER
			;Adjust out_ptr to equal buf_start
			;Thus wrapping around the circular queue
			LDR R3, [R1, #BUF_START]
			STR R3, [R1, #OUT_PTR]

DEQUEUE_CLEAR_PSR
			;Clear the PSR C flag
			MRS R1, APSR
			MOVS R3, #0x20
			LSLS R1, R1, #24
			BICS R1, R1, R3
			MSR	APSR, R1
			
			;Successfully end the operation
			B END_DEQUEUE
			
DEQUEUE_FAILURE
			;Set PSR C flag to 1
			MRS R1, APSR
			MOVS R3, #0x20
			LSLS R3, R3, #24
			ORRS R1, R1, R3
			MSR APSR, R1
			
END_DEQUEUE
			POP {R1, R2, R3, R4}
			BX	LR
			
;--------------------------------------------
EnQueue
;EnQueue: Add an element to the circular FIFO Queue
;Inputs:
	;R0 - Character to enqueue
	;R1 - Address of the Queue record
;Outputs:
	;PSR C flag (failure if C = 1, C = 0 otherwise.)
;--------------------------------------------'

			PUSH {R2, R3, R4}
			
			;If num_enqd >= size of the queue
			;Then set PSR C flag to 1 indicating
			;the error that an element was not inserted
			;into a full queue
			
			LDRB R3, [R1, #NUM_ENQD]
			LDRB R4, [R1, #BUF_SIZE]
			CMP R3, R4
			BGE QUEUE_FULL
			B BEGIN_ENQUEUE
			
QUEUE_FULL
			;Set PSR C flag to 1
			MRS R1, APSR
			MOVS R3, #0x20
			LSLS R3, R3, #24
			ORRS R1, R1, R3
			MSR APSR, R1
			B END_ENQUEUE
			
BEGIN_ENQUEUE
			
			;Load mem address of in_ptr
			;and then store the value to be enqueued
			;intot he value at that memory address
			LDR R3, [R1, #IN_PTR]
			STRB R0, [R3, #0]
			
			;Increment value of in_ptr by 1, 1 value past
			;The queue item. Then store back in IN_PTR
			ADDS R3, R3, #1
			STR R3, [R1, #IN_PTR]
			
			;Increment number of enqueued elements
			LDRB R3, [R1, #NUM_ENQD]
			ADDS R3, R3, #1
			STRB R3, [R1, #NUM_ENQD]
			
			;If IN_PTR is >= BUF_PAST
			;Loop around and adjust inPtr to beginning of
			;the queue buffer
			LDR R3, [R1, #IN_PTR]
			LDR R4, [R1, #BUF_PAST]
			
			CMP R3, R4
			BGE WRAP_ENQUEUE
			
			;Clear the PSR C flag confirming successful result
			MRS R2, APSR
			MOVS R3, #0x20
			LSLS R2, R2, #24
			BICS R2, R2, R3
			MSR	APSR, R2
			
			B END_ENQUEUE
			
WRAP_ENQUEUE
			;Adjust in_ptr to beginning of queue buffer
			LDR R2, [R1, #BUF_START]
			STR R2, [R1, #IN_PTR]
			
			;Clear the PSR C flag confirming successful result
			MRS R2, APSR
			MOVS R3, #0x20
			LSLS R2, R2, #24
			BICS R2, R2, R3
			MSR	APSR, R2
			
END_ENQUEUE
			
			POP {R2, R3, R4}
			BX LR

;--------------------------------------------

;Send a character out of UART0 using interrupts
;Inputs
;	R0 - Character to enqueue to TxQueue
;Return - N/A
;--------------------------------------------
PutChar
			PUSH {R0, R1, LR}
			
REPEAT_ENQ
			
			;Load input params to initalize queue structure
			LDR R1, =TxQueueRecord
			
			;Mask all other interrupts
			CPSID I
			
			;Critical section -> enqueue character
			;Enqueue character that's already in R0
			BL	EnQueue
			
			;Enable interrupts
			CPSIE I
			
			BCS REPEAT_ENQ
			
			;Enable UART0 Transmitter, reciever, and rx interrupt
			LDR R0, =UART0_BASE
		    MOVS R1,#UART0_C2_TI_RI
            STRB R1,[R0,#UART0_C2_OFFSET]
			
			;Pop original register values off the stack
			POP {R0, R1, PC}

;--------------------------------------------
            
;Receive a character from UART0 using interrupts
;Inputs - N/A
;Return
; R0 - Character dequeued from RxQueue
;--------------------------------------------
GetChar
	PUSH {R1, R2, LR} ; Push varibles on the stack to avoid loss
	
	LDR R1, =RxQueueRecord

REPEAT_DEQ

	;Mask all interrupts
	CPSID I	
	
	;Critical code section - dequeue
	BL DeQueue
	
	;Re enable interrupts
	CPSIE I
	
	BCS REPEAT_DEQ
	
	POP {R1, R2, PC}
			
;--------------------------------------------

;R0 = memory location to store string
;R1 = Buffer capacity (numChars)

;--------------------------------------------
GetStringSB

		PUSH {R1, R2, R3, LR}
		MOVS R2, #0 ;Initalize string offset to zero
		
		
TAKE_INPUT
        
		PUSH {R0}
		;Grab the next character of input and store in R3
        BL      GetChar
		MOVS R3, R0
		POP {R0}
		
		;check if character is a carrige return
		CMP R3, #13
		BEQ END_GET_STR
		
		;If all characters have been processed
		;and another comes in, dont echo and reset.
		CMP R1, #0
        BEQ TAKE_INPUT
		
		;Echo character to the terminal
		PUSH {R0} ;Preserve state of R0 and LR
		MOVS R0, R3 ;Move char in R3 for transit
		BL PutChar
		POP {R0}
		
		;String[i] = input char
		STRB R3, [R0, R2]
		
		;Decrement number of characters left to read
        SUBS    R1, R1, #1
		;Add to offset index for string
		ADDS	R2, R2, #1
		
        B TAKE_INPUT
		
END_GET_STR
		
		;null terminate String
		MOVS R3, #0
		STRB R3, [R0, R2]
		
		;Pop PC returns nested subroutine
		POP {R1, R2, R3, PC}
		
		
PrintCharLF
		;Print character in R0
		;In addition to a carrige return and a line feed
		;Used to produce the command 'menu' with single char inputs
		
		PUSH {R0, LR}
		;Echo the char back to the user
		BL PutChar
			
		;Print CR and LF to the screen
		MOVS R0, #0x0D
		BL PutChar
			
		MOVS R0, #0x0A
		BL PutChar
		
		POP {R0, PC}
		
;--------------------------------------------
		
;R0 = memory location of string to print
;R1 = Buffer capacity (numChars)
PutStringSB
;--------------------------------------------

		PUSH {R0, R1, R2, R3, LR}
		
		;Determine the length of the string before printing
		BL LengthStringSB
		MOVS R1, R2
		
READ_CHAR
		
		;If all characters have been processed
		;End subroutine execution
		CMP R1, #0
        BEQ END_PUT_STR
		
		;Grab the next character of input and store in R3
        LDRB R3, [R0, #0]
		
		;Echo character to the terminal
		PUSH {R0} ;Preserve state of R0 and LR
		MOVS R0, R3 ;Move char in R3 for transit
		BL PutChar
		POP {R0}
		
		;Decrement number of characters left to read
        SUBS    R1, R1, #1
		;Add to offset index for string
		ADDS	R0, R0, #1
		
        B READ_CHAR
		
END_PUT_STR

		;Pop PC returns nested subroutine
		;Return with pointer at last char of string in R0
		POP {R0, R1, R2, R3, PC}
		
;--------------------------------------------
		

;R0 = memory location of string 
;R1 = Buffer capacity (numChars)
;R2 = Output num of String length
LengthStringSB
;--------------------------------------------

		PUSH {R0, R1, R3, R4, LR}
		MOVS R1, #MAX_STRING
		MOVS R2, #0; Initalize length to zero.
		MOVS R4, #0; Initalize STR offset to zero
		
ADD_TO_LEN

		;if legth is >= buffer, return
		CMP R2, R1
        BGE END_GET_LEN
		
		;Grab the next character of input and store in R3
        LDRB R3, [R0, R4]
		
		;check if character is a null terminator
		CMP R3, #0
		BEQ END_GET_LEN
		
		;Add to string offset
		ADDS R4, R4, #1 
		;Add 1 to max
		ADDS R2, R2, #1
		
        B ADD_TO_LEN
		
END_GET_LEN

		;Pop PC returns nested subroutine
		POP {R0, R1, R3, R4, PC}
		
;--------------------------------------------

DIVU
;R1 / R0 = R0 Remainder R1
;--------------------------------------------
			PUSH {R2,R3}		; Preserve state of Registers, will be using for computation
			CMP R0, #0
			BEQ	SET_C
			B NO_ERR 
			
SET_C
			
			MRS R2, APSR
			MOVS R3, #0x20
			LSLS R3, R3, #24
			ORRS R2, R2, R3
			MSR APSR, R2
			
			B RETURN
NO_ERR		
			MOVS R2, #0 		; Move beginning quotient to R2
			
DIVIDE_OP			
			CMP R1, R0
			BLO END_DIVIDE_WHILE
			
			SUBS R1, R1, R0 	; R1 = dividend - divisor
			ADDS R2, R2, #1 	; Quotient += 1
			
			B DIVIDE_OP
			
END_DIVIDE_WHILE
			MOVS R0, R2
			
			MRS R2, APSR
			MOVS R3, #0x20
			LSLS R2, R2, #24
			BICS R2, R2, R3
			MSR	APSR, R2
			
RETURN		
			POP {R2, R3}		;Return registers to previous state
			BX LR 				;Jump out of subroutine
			
;--------------------------------------------
		
Init_UART0_IRQ
;Initalize UART0 for Serial Driver
;---------------------------------------------------------------

			;Allocate R0-2 for Ri=k 
			;Store prevoius values for restoration
			PUSH {R0, R1, R2, LR}

			;Initalize rxQueue
			LDR R1, =RxQueueRecord
			LDR R0, =RxQueue
			MOVS R2, #Q_BUF_SZ

			BL InitQueue

			LDR R1, =TxQueueRecord
			LDR R0, =TxQueue
			MOVS R2, #Q_BUF_SZ
			
			BL InitQueue

		    ;Select MCGPLLCLK / 2 as UART0 clock source
		     LDR R0,=SIM_SOPT2
		     LDR R1,=SIM_SOPT2_UART0SRC_MASK
		     LDR R2,[R0,#0]
		     BICS R2,R2,R1
		     LDR R1,=SIM_SOPT2_UART0_MCGPLLCLK_DIV2
		     ORRS R2,R2,R1
		     STR R2,[R0,#0]
		    ;Enable external connection for UART0
		     LDR R0,=SIM_SOPT5
		     LDR R1,= SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
		     LDR R2,[R0,#0]
		     BICS R2,R2,R1
		     STR R2,[R0,#0]
		    ;Enable clock for UART0 module
		     LDR R0,=SIM_SCGC4
		     LDR R1,= SIM_SCGC4_UART0_MASK
		     LDR R2,[R0,#0]
		     ORRS R2,R2,R1
		     STR R2,[R0,#0]
		    ;Enable clock for Port A module
		     LDR R0,=SIM_SCGC5
		     LDR R1,= SIM_SCGC5_PORTA_MASK
		     LDR R2,[R0,#0]
		     ORRS R2,R2,R1
		     STR R2,[R0,#0]
		    ;Connect PORT A Pin 1 (PTA1) to UART0 Rx (J1 Pin 02)
		     LDR R0,=PORTA_PCR1
		     LDR R1,=PORT_PCR_SET_PTA1_UART0_RX
		     STR R1,[R0,#0]
		    ;Connect PORT A Pin 2 (PTA2) to UART0 Tx (J1 Pin 04)
		     LDR R0,=PORTA_PCR2
		     LDR R1,=PORT_PCR_SET_PTA2_UART0_TX
		     STR R1,[R0,#0] 
		     
		     ;Disable UART0 receiver and transmitter
		     LDR R0,=UART0_BASE
		     MOVS R1,#UART0_C2_T_R
		     LDRB R2,[R0,#UART0_C2_OFFSET]
		     BICS R2,R2,R1
		     STRB R2,[R0,#UART0_C2_OFFSET]

		     ;Init NVIC for UART0 Interrupts
		     ;Set UART0 IRQ Priority
		     LDR R0, =UART0_IPR
			 
			 LDR R1, =NVIC_IPR_UART0_MASK
			 
		     LDR R2, =NVIC_IPR_UART0_PRI_3

		     LDR R3, [R0, #0]
			 
			 BICS R3, R3, R1
			 
             ORRS R3, R3, R2

	         STR R3, [R0, #0]

             ;Clear any pending UART0 Interrupts
		     LDR R0, =NVIC_ICPR
	 	     LDR R1, =NVIC_ICPR_UART0_MASK
		     STR R1, [R0, #0]

		     ;Unmask UART0 interrupts
             LDR R0, =NVIC_ISER
		     LDR R1, =NVIC_ISER_UART0_MASK
		     STR R1, [R0, #0]
			 
			 ;Init UART0 for 8N1 format at 9600 Baud,
			 ;and enable the rx interrupt
			 
			 LDR R0, =UART0_BASE
			 
			 MOVS R1,#UART0_BDH_9600
             STRB R1,[R0,#UART0_BDH_OFFSET]
             MOVS R1,#UART0_BDL_9600
             STRB R1,[R0,#UART0_BDL_OFFSET]
             MOVS R1,#UART0_C1_8N1
             STRB R1,[R0,#UART0_C1_OFFSET]
             MOVS R1,#UART0_C3_NO_TXINV
             STRB R1,[R0,#UART0_C3_OFFSET]
             MOVS R1,#UART0_C4_NO_MATCH_OSR_16
             STRB R1,[R0,#UART0_C4_OFFSET]
             MOVS R1,#UART0_C5_NO_DMA_SSR_SYNC
             STRB R1,[R0,#UART0_C5_OFFSET]
             MOVS R1,#UART0_S1_CLEAR_FLAGS
             STRB R1,[R0,#UART0_S1_OFFSET]
             MOVS R1, \
             #UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS
             STRB R1,[R0,#UART0_S2_OFFSET] 
			 
			 ;Enable UART0 Transmitter, reciever, and rx interrupt
			 MOVS R1,#UART0_C2_T_RI
             STRB R1,[R0,#UART0_C2_OFFSET] 
				
	       	 ;Pop prevous R0-2 values off the stack.
			 POP {R0, R1, R2, PC}
			
;--------------------------------------------			
Init_PIT_IRQ
;Init_PIT_IRQ: Initalize the PIT to generate an 
;interrupt from channel 0 every 0.01 seconds. 

;The timer start value stored to PIT_LDVAL 
;will be equal to 239,999 to simulate
;the 0.01 interval between interrupts

;the PIT interrupts will be initalized on the NVIC
;with the highest priority level of zero

;Inputs: N/A
;Outputs: N/A
;---------------------------------------------

			CPSID I
			
			PUSH {R0, R1, R2, LR}
			
			LDR R0, =SIM_SCGC6
			LDR R1, =SIM_SCGC6_PIT_MASK
			
			LDR R2, [R0, #0]
			
			;Set only the PIT bit on SIM_SCGC6
			ORRS R2, R2, R1
			
			;Store set bit back on to the register
			STR R2, [R0, #0]
			
			;Disable timer 0 TODO: Is this appropriate?
			LDR R0, =PIT_CH0_BASE
			LDR R1, =PIT_TCTRL_TEN_MASK
			LDR R2, [R0, #PIT_TCTRL_OFFSET]
			BICS R2, R2, R1
			STR R2, [R0, #PIT_TCTRL_OFFSET]
			
			;Enable the PIT timer module
			LDR R0, =PIT_BASE
			
			;Enable the FRZ to stop timer in debug mode
			LDR R1, =PIT_MCR_EN_FRZ
			
			STR R1, [R0, #PIT_MCR_OFFSET]
			
			;Request interrupts every 0.01 seconds
			LDR R0, =PIT_CH0_BASE
			LDR R1, =PIT_LDVAL_10ms ;239,999
			
			STR R1, [R0, #PIT_LDVAL_OFFSET]
			
			;Enable PIT timer channel 0 for interrupts
			LDR R0, =PIT_CH0_BASE
			
			;Interrupt enabled mask to write to the register
			MOVS R1, #PIT_TCTRL_CH_IE
			STR R1, [R0, #PIT_TCTRL_OFFSET]
			
			;Initalize PIT Interrupts in the NVIC
			;Make sure they are set to the highest priority (0)
			
			;Unmask PIT Interrupts
			LDR R0, =NVIC_ISER
			LDR R1, =PIT_IRQ_MASK
			STR R1, [R0, #0]
			
			;Set PIT Interrupt Priority
			LDR R0, =PIT_IPR
			LDR R1, =(PIT_IRQ_PRI << PIT_PRI_POS)
			STR R1, [R0, #0]
			
			CPSIE I
			
			POP {R0, R1, R2, PC}

;--------------------------------------------
			 
;PutNumU: Print ASCII value to terminal screen
;Inputs:
	;R0 - Character to print
;Outputs:
	;N/A
;--------------------------------------------'
PutNumU

		;Divide R0 value by 10
		;continually printing the remainder
		
		PUSH {R0, R1, R2, LR}

		;Initalize Array offset to Zero
		MOVS R2, #0
		
DIV_NUM
		;Num is too small to divide by 10
		;finish subroutine
		CMP R0, #10
		BLT COMPLETE_PUT_NUM
		
		;Move dividend to R1, set divisor to 10
		MOVS R1, R0
		MOVS R0, #10
		
		;R1 / R0 = R0 Remainder R1
		BL DIVU
		
		;Print remainder stored in R1
		PUSH {R0}
		LDR R0, =StringReversal
		
		STRB R1, [R0, R2]
		ADDS R2, R2, #1
		
		POP {R0}
		
		;repeat until num is no longer divisible by 10
		B DIV_NUM

COMPLETE_PUT_NUM

		;Convert to ASCII Value
		ADDS R0, R0, #'0'
		BL PutChar
		
		;TODO: Check if this works
		SUBS R2, R2, #1
		
PRINT_CHAR		
		;Iterate over array and print
		LDR R0, =StringReversal
		
		CMP R2, #0
		BLT END_PUTNUM
		
		LDRB R1, [R0, R2]
		MOVS R0, R1
		
		;Convert to ASCII Character and Print
		ADDS R0, R0, #'0'
		BL PutChar
		
		SUBS R2, R2, #1
	
		B PRINT_CHAR
		
END_PUTNUM
		;restore previous values to register and return
		POP {R0, R1, R2, PC}

			
;-------------------------------------------------------------------

;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    Dummy_Handler      ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendableSrvReq (pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 xfer complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 xfer complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 xfer complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 xfer complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:command complete; read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:I2C1
            DCD    Dummy_Handler      ;26:SPI0 (all IRQ sources)
            DCD    Dummy_Handler      ;27:SPI1 (all IRQ sources)
            DCD    UART0_ISR		  ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:UART1 (status; error)
            DCD    Dummy_Handler      ;30:UART2 (status; error)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:TPM2
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    PIT_ISR      	  ;38:PIT (all IRQ sources)
            DCD    Dummy_Handler      ;39:I2S0
            DCD    Dummy_Handler      ;40:USB0
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:Segment LCD
            DCD    Dummy_Handler      ;46:PORTA pin detect
            DCD    Dummy_Handler      ;47:PORTC and PORTD pin detect
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
            AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
TimeString			DCB " x 0.01 s", 0
AccessCodePrompt	DCB "Enter the access code.", 0
Granted				DCB "--Access granted", 0
Denied				DCB "--Access denied", 0
Complete			DCB "Mission completed!", 0
SecretCode			DCB "25015110", 0
;>>>>>   end constants here <<<<<
            ALIGN
;****************************************************************
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<

;Rx Queue
;Memory allocated to store String input from user
RxQueue 	  SPACE Q_BUF_SZ	
;6 Byte buffer to store queue information 
RxQueueRecord SPACE Q_REC_SZ
	
			ALIGN

;Tx Queue
;Memory allocated to store String input from user
TxQueue 	  SPACE Q_BUF_SZ	
;6 Byte buffer to store queue information 
TxQueueRecord SPACE Q_REC_SZ
	
			ALIGN
	
;Memory allocated to store String input from user
Queue 		SPACE Q_BUF_SZ	
;6 Byte buffer to store queue information 
QueueRecord SPACE Q_REC_SZ
	
			ALIGN
	
StringReversal	SPACE 2
			ALIGN
RunStopWatch	SPACE 1
			ALIGN
Count			SPACE 4
InputString		SPACE MAX_STRING
	
;>>>>>   end variables here <<<<<
            ALIGN
            END
