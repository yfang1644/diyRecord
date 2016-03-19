///////////////////////////////////////////////////////////////////////////
//NAME:     main.asm                                                     //
//DATE:     2010-09-05                                                   //
//PURPOSE:  EC2600 ver. 2 on ADSP-21375                                  //
///////////////////////////////////////////////////////////////////////////

#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.extern _initPLL;
.extern _initPCG;
.extern _initSDRAM;
.extern _checkSDRAM;
.extern _initSRU;
.extern _initTimer;
.extern _initUART;
.extern _initPanel;
.extern _initSPORT;
.extern _remoteID;

.extern _parametersInit;

.extern _digitalProcessing;
.extern _setNewParameters;
.extern _initSineTable;
.extern _blink88, _switchInterval, _digitBlink;
.extern _levelBlink, _levelIndicator;
.extern _keyProcessing;

.extern _Company, _DeviceInfo, _SoftwareVersion;
.extern _rcvCounter, _uart_rxbuf;

#define RESERVED_INTERRUPT	jump(pc, 0);jump(pc, 0);jump(pc, 0);jump(pc, 0);

.section/pm		seg_rth;				// Runtime header segment
___EMUI:		RESERVED_INTERRUPT;		// 0x00: Emulator interrupt (highest priority, read-only, non-maskable)

___RSTI:	nop;
			jump _main;
			jump _main;
			jump _main;
___IICDI:	RESERVED_INTERRUPT;		// Access to illegal IOP space
___SOVFI:	RESERVED_INTERRUPT;		// status/loop/PC stack overflow
___TMZHI:	RESERVED_INTERRUPT; 	// high priority timer
___SPERRI:	RESERVED_INTERRUPT;		// SPORT Error interrupt
___BKPI:	RESERVED_INTERRUPT;		// Hardware breakpoint interrupt
			RESERVED_INTERRUPT;
___IRQ2I:	RESERVED_INTERRUPT;
___IRQ1I:	rti(DB);
			bit set ustat4 BIT_30;
			bit clr IMASK IRQ1I;
			nop;
___IRQ0I:	RESERVED_INTERRUPT;
___P0I:		RESERVED_INTERRUPT;		// Peripheral interrupt 0
___P1I:		RESERVED_INTERRUPT;		// Peripheral interrupt 1
___P2I:		RESERVED_INTERRUPT;		// Peripheral interrupt 2
/***********************************************************************
 *   以ADC中断为核心
 * 2 ADCs and 6 DACs are transferred via DMA
 * Interrupt (P3I) issued after 2 word ADC finished
 ***********************************************************************/
___P3I:
			PUSH STS, FLUSH CACHE;
			jump (pc, _digitalProcessing)(DB);
			bit set MODE1 SRRFL|SRRFH|SRD1H|SRD1L|SRD2H|SRD2L;
			nop;

___P4I:		RESERVED_INTERRUPT;		// Peripheral interrupt 4
___P5I:		RESERVED_INTERRUPT;		// Peripheral interrupt 5
___P6I:		RESERVED_INTERRUPT;		// Peripheral interrupt 6
___P7I:		RESERVED_INTERRUPT;		// Peripheral interrupt 7
___P8I:		RESERVED_INTERRUPT;		// Peripheral interrupt 8
___P9I:		RESERVED_INTERRUPT;		// Peripheral interrupt 9
___P10I:	RESERVED_INTERRUPT;		// Peripheral interrupt 10
___P11I:	RESERVED_INTERRUPT;		// Peripheral interrupt 11
___P12I:	RESERVED_INTERRUPT;		// Peripheral interrupt 12
___P13I:	RESERVED_INTERRUPT;		// Peripheral interrupt 13
/*****************************************************************************
 * UART receive interrupt (transmition moved to DMA mode since version.43)
 * i2 -> _uart_rxbuf
 * r9, r10, m2 used
 *****************************************************************************/
___P14I:	PUSH STS, FLUSH CACHE;
			bit set MODE1 SRRFH|SRD1L;  // UART0 ISR
			ustat1 = dm(UART0IIR);
			bit tst ustat1 UARTRBFI;

			if not TF jump (pc, _receive_miss);
			r9 = dm(UART0RBR);
			r10 = 0x28;					// '(';
			r10 = r10 - r9;

			if EQ jump (pc, 2);
			r10 = dm(_rcvCounter);
			m2 = r10;
			i2 = _uart_rxbuf;

			r10 = r10 + 1, dm(m2, i2) = r9;
			r9 = UART_BUF_SIZE;
			comp(r10, r9);
			if GE r10 = r10 - r10;		// RcvCounter>UART buffer,set to 0

			dm(_rcvCounter) = r10;		// r8 still in delay slot
_receive_miss:
			rti(DB);
			bit clr MODE1 SRRFH|SRD1L;
			POP STS, FLUSH CACHE;

___CB7I:	RESERVED_INTERRUPT;
___CB15I:	RESERVED_INTERRUPT;
___TMZLI:	bit SET MODE1 SRRFH;		// register group switches, 2 delays
			bit TST ustat4 BIT_20;		// LED blink
			r12 = dm(_blink88);
			if not TF jump (pc, 2), else r12 = r12 - 1;
			dm(_blink88) = r12;

//			r12 = dm(_levelIndicator);
//			r12 = r12 - 1;
//			dm(_levelIndicator) = r12;
			bit TST ustat4 BIT_28;
			if TF jump _key_disabled;
			bit TST ustat4 BIT_30;		// switch enable
			if TF jump _key_on;

			bit TGL FLAGS FLG8|FLG9;
			bit TST IMASK IRQ1I;
			r12 = dm(_switchInterval);
			if TF jump (pc, _no_key), else r12 = r12 - 1;
			if GT jump (pc, 2);
			bit SET IMASK IRQ1I;
			dm(_switchInterval) = r12;
_no_key:
_key_on:
_key_disabled:
			bit CLR MODE1 SRRFH;
			rti;
/*
___FIXI:	RESERVED_INTERRUPT;		// fixed point overflow
___FLTOI:	RESERVED_INTERRUPT;		// floating point overflow
___FLTUI:	RESERVED_INTERRUPT;		// floating point underflow
___FLTII:	RESERVED_INTERRUPT;		// floating point invalid
___EMULI:	RESERVED_INTERRUPT;		// Emulator low priority interrupt
___SFT0I:	RESERVED_INTERRUPT;		// user interrupts 0..3
___SFT1I:	RESERVED_INTERRUPT;
___SFT2I:	RESERVED_INTERRUPT;
___SFT3I:	RESERVED_INTERRUPT;
*/
.section /pm seg_pmco;

_main:
		call _systemInit;
		bit SET FLAGS FLG0O|FLG8O|FLG9O;	// Enable Flag8 and Flag9 output
		call _initPLL;			// Initializes PLL(core clock CCLK 33MHz*8)
		call _checkSDRAM;		// Initializes SDRAM (SDCLK clock 2)
		call _initSRU;			// Initializes the SRU & DAI/DPI pins
		call _initPanel;		// Power-on panel lock status check
//		call _checkSDRAM;

		call _parametersInit;

		call _initPCG;
		call _initSPORT;		// Initializes serial ports (SPORTS)
		call _initSineTable;	// initializes sine table

		call _initUART;			// Initializes UART
		call _initTimer;
		bit set MODE1 IRPTEN;	// Enable global interrupts
main_loop:
		idle;
//		bit CLR IMASK P3I;
		call (pc, _setNewParameters);

		bit TST ustat4 BIT_30;
		if TF call (pc, _keyProcessing);

//		bit SET IMASK P3I;
		r0 = dm(_blink88);
		r0 = pass r0;
		if LT call (pc, _digitBlink);

		r0 = dm(_levelIndicator);
		r0 = r0 + 1;
		dm(_levelIndicator) = r0;
		BTST r0 by 6;
		if not SZ call (pc, _levelBlink);

		jump (pc, main_loop);
		nop;
_main.end:


_systemInit:
		bit set MODE2 CADIS;	// Clear cache for rev 0 hardware
								// MODE2 is a latent write
		nop;					// MODE1 latency
		read cache 0;			// as some 2136x isn't enabled properly
		flush cache;
		bit clr MODE2 CADIS;

		LIRPTL = 0;
		IMASKP = 0;
		IMASK = 0;
		IRPTL = 0;				// Clear interrupt latch for hardware
		MODE1 = 0;

	// Set to 32-bit mode (RND32), disable CBUFEN(circular buffer)
	// We want to disable IRPTEN, saturation, SIMD,
	// broadcast loads, bit reversal and TRUNCATE.
	// global interrupt (IRPTEN) enable, interrupt nesting (NESTM) disable
		bit set MODE1 SRD2L|SRD2H|SRD1L|SRD1H|SRRFH|RND32;	// secondary DAGs
		lcntr = 2, do (pc, end_setup) until lce;
			nop;
			m5 = 0; m6 = 1; m7 = -1;
			m13 = 0; m14 = 1; m15 = -1;
			l0 = 0; l1 = 0; l2 = 0; l3 = 0;
			l4 = 0; l5 = 0; l6 = 0; l7 = 0;
			l8 = 0; l9 = 0; l10 = 0; l11 = 0;
			l12 = 0;l13 = 0;l14 = 0; l15 = 0;
			b0 = 0;	b1 = 0;	b2 = 0;	b3 = 0;
			b4 = 0; b5 = 0; b6 = 0; b7 = 0;
			b8 = 0; b9 = 0; b10 = 0; b11 = 0;
			b12 = 0; b13 = 0; b14 = 0; b15 = 0;
			f11 = 2.0; m0 = MAXBUFFER; m1 = 2;
end_setup:
	// primary DAGs, set ALUSAT and TRUNC bits
		bit clr MODE1 TRUNCATE|SRD2L|SRD2H|SRD1L|SRD1H|SRRFH;

		MMASK = BDCST1|BDCST9|TRUNCATE|BR0|BR8;

		jump  ___lib_setup_stacks;
_systemInit.end:

/*
 * The following initializations rely on several values being established
 * externally, typically by the linker description file.
 */

.extern ldf_stack_space;	/* The base of the stack */
.extern ldf_stack_length;	/* The length of the stack */

/*
 * The linker description file will typically look something like:
 *
 *	MEMORY
 *	{
 *		heap_memory  { START(0x2c000) LENGTH(0x2000) TYPE(DM RAM) }
 *		stack_memory { START(0x2e000) LENGTH(0x2000) TYPE(DM RAM) }
 *	}
 *
 *	...
 *
 *	SECTIONS
 *	{
 *	    stack
 *	    {
 *		ldf_stack_space = .;
 *		ldf_stack_length = MEMORY_SIZEOF(stack_memory);
 *	    } > stack_memory
 *
 *	    heap
 *	    {
 *		ldf_heap_space = .;
 *		ldf_heap_length = MEMORY_SIZEOF(heap_memory);
 *	    } > heap_memory
 *	}
 */

___lib_setup_stacks:
//		PX = pm(___lib_stack_space);
		PX = ldf_stack_space;
		R0 = PX2;
//		PX = pm(___lib_stack_length);
		PX = ldf_stack_length;
		R2 = PX2;
	/* R0 now has stack start, R2 has stack length */
	/* Goal here is that stack start + stack length should be even */
//		R2 = R2 + R0;
//		BTST R2 BY 0;
//		if SZ R2 = R2 - 1;
//		R2 = R2 - R0;
		r2 = r2 - 1;
		PX2 = R2;
		R1 = R0 + R2, B7 = R0;
		R1 = R1 - 1, L7 = R2;
		I7 = R1;
		bit set MODE1 SRD1H; // Enable secondary DAG1
		B6 = B7; // Primary DAG, done in latency slot
		B7 = R0;
		B6 = B7;
		L7 = R2;
		bit clr MODE1 SRD1H; // Enable primary DAG1
		L6 = L7; // Secondary DAG, done in latency slot

		I6 = I7;
		RTS (DB);
		L6 = L7;
		modify(i7, -2);
___lib_setup_stacks.end:

