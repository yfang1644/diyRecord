////////////////////////////////////////////////////////////////////////////
//                                                                        //
// This program enables UART0 in transmit and receive mode. The UART0     //
// transmit signal is connected to DPI pin 9                              //
//                                                                        //
////////////////////////////////////////////////////////////////////////////

#include <def21375.h>

#include "lib_glob.h"
#include "constant.h"
#include "flash.h"

.extern _sectorErase, _writeFlash, _writeFlash_no_erase;

.extern _HexPhaseData;

.extern _calculateFIR, _loadFromFlash, _smoothPhase;

.section/dm seg_dmda;
.global _rcvCounter, _uart_rxbuf;
.var _rcvCounter = 0;
.var _uart_txbuf[256];
.var _uart_rxbuf[N_OCTAVE*4+10];

.var UartCommandTable[] =
	'D', 8+1024, uart_D,		// (IDD, flash program, sector+part+512bytes
	'h', 8, uart_hello,			// (IDhello, PC connect
	'b', 6, uart_bye,			// (IDbye, PC disconnect
	'P', 6+4*N_OCTAVE, uart_P,	// (IDPCC, upload Phase, Channel+512bytes
	'S', 6,	uart_S,				// (IDSFF,  Save Phase Data to FLASH
	'L', 8,	uart_L;				// (IDLFFCC,  Load Phase Data from FLASH

.section/pm seg_pmco;

#define MASKP14	(0x1f<<10)
#define UART0Rx	(0x13<<10)
.global _initUART;
_initUART:
	//================================================================
	// initialize UART:
	// Sets the Baud rate for UART0
	// i2 and i3 point to rxbuf and txbuf respectively
	// Enable receice interrupt
	// (transmit interrupt enable/disable depends on receiving
	//----------------------------------------------------------------
	ustat1 = UARTDLAB;
	dm(UART0LCR) = ustat1;			// enables access to Divisor register

// x=Pclk / (16 x 19200bps) = 402.8=0x193
// Pclk(peripheral clock=core clock/2)
// 0x1AB=426.6 @cclk=16.384*16
// 0x1AE=429.6 @cclk=16.5*16
// 0x192=403, @cclk=16.5*15
// 0x178=376, @cclk=16.5*14
// 0x15d=349, @cclk=16.5*13
// 0x142=322, @cclk=16.5*12
// 0x10D=269, @cclk=16.5*10
// 0x0D7=215, @cclk=16.5*8
// 0x06B=107, @cclk=16.5*4
	r0=0x92;
	dm(UART0DLL) = r0;
	dm(UART0DLH) = m6;

// Configures the UART LCR
	ustat1 = UARTWLS8;		// word length 8
//		|UARTPEN			// parity enable for odd parity
//		|UARTSTB;			// two stop bits
	dm(UART0LCR) = ustat1;

	ustat1 = UARTEN;
	dm(UART0RXCTL) = ustat1;			// enable UART0 receiver interrupt

	dm(IMUART0TX) = m6;					// DMA for UART transmitt, IM=1

	ustat1 = dm(PICR2);
	bit clr ustat1 MASKP14;
	bit set ustat1 UART0Rx;				// UART0 receive interrupt P13
	dm(PICR2) = ustat1;

	ustat1 = UARTRBFIE;
	dm(UART0IER) = ustat1;				// Enables UART receive interrupt

	bit set IMASK P14I;					// Unmask the UART interrupt
	rts;
_initUART.end:

/*
	Function: get one data from contiuous 2 byte uart buffer
	           (convert ASCII to digits)
	Import: i12: uart buffer data related start address,
	Changed Register: r0, r1, r4
	Return: r0=eval(char), r4=error code;
*/
_GetNumberFromUart:
	r4 = 0x30;							// '0'
	bit SET ustat4 BIT_14;				// set ERROR bit, overRange[0~9]

	r0 = r0 - r0, puts = r10;
	r10 = 10;
	lcntr = 2, do GetNumberFromUart0 until lce;
		r0 = r0 * r10(UUI), r1 = pm(i12, m14);
   		r1 = r1 - r4;				// convert ASCII to digit
		if LT jump (pc, Number_Error)(LA), else comp(r1, r10);	// x<0
		if GE jump (pc, Number_Error)(LA), else r0 = r0 + r1;	// x>9
		nop;
GetNumberFromUart0:
		nop;

	bit CLR ustat4 BIT_14;
Number_Error:
	r4 = 0x3231;						// errno = "21"
	rts(DB);
	r10 = gets(1);
	alter(1);
_GetNumberFromUart.end:


.global _setNewParameters;
/*****************************************************************
 *
 *
 *****************************************************************/
_setNewParameters:

	r12 = dm(_rcvCounter);
	r10 = 4;
	comp(r12, r10);
	if LT jump (pc, exitUART);

	r4  = dm(_uart_rxbuf);
	r10 = 0x28;							// '(' Ensure a start BYTE
	comp (r4, r10);						// bug in new board
	if NE jump (pc, exitUART);

	i12 = _uart_rxbuf + 1;
	call (pc, _GetNumberFromUart);		// get ID from uart_rxbuf

	r4  = 1;							// remoteID=01
	comp (r0, r4), r9 = pm(i12, m14);	// is these data for me?
	if NE jump (pc, exitUART);			// not for me

	i5  = UartCommandTable;				// r9=letters or $
	lcntr = @UartCommandTable/3, do (pc, checkValid) until lce;
		r10 = dm(i5, m6);
		comp(r9, r10), r10 = dm(i5, m6);
		if NE jump (pc, checkValid), else comp(r12, r10);
		if GE jump (pc, checkValidMatch)(LA);
		nop;
checkValid:
		modify(i5, m6);

exitUART:
	rts;

checkValidMatch:
	i12 = dm(i5, m5);
	dm(UART0TXCTL) = m5;				// disable DMA
	jump (m13, i12)(DB);
	r0  = _uart_txbuf;
	dm(IIUART0TX) = r0;					// DMA index register
_setNewParameters.end:

/*
	Function: send uart tx buffer to PC
	Import:	 R4(tx buffer 's length:byte numbers)
	Changed registers: r8, i4, i10
	Export: No
*/
_FillTxBuffer:
	i4  = _uart_rxbuf;
	i10 = _uart_txbuf;

	r8  = dm(i4, m6);
	lcntr = r4, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	rts;
_FillTxBuffer.end:


/*
	Function: convet 2-bytes ASCII(from PC) into user program data structure
	Import: R4(numbers)
			I10: user program data pointer(SRAM)
			I4: uart rx buffer pointer
	Changed register: r7, r8, r9, r10, r12
	Export:No
*/
_ConvertFromHEX:

	r7  = 7;
	r9  = 0x39;
	r10 = 0x30;
	lcntr = r4, do ConvertFromHEX0 until lce;
		r8 = dm(i4, m6);
		comp(r8, r9);
		if GT r8 = r8 - r7;				// 'A'-'F'

		r12 = r8 - r10, r8 = dm(i4, m6);
		comp(r8, r9);
		if GT r8 = r8 - r7;				// 'A'-'F'
		r8 = r8 - r10;
		r8 = r8 OR LSHIFT r12 BY 4;
ConvertFromHEX0:
		pm(i10, m14) = r8;

	rts;
_ConvertFromHEX.end:


uart_hello:								// Communication Check, UART online
	r4  = 8;
	dm(CUART0TX) = r4;					// DMA counter
	call (pc, _FillTxBuffer);

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA
uart_hello.end:


uart_bye:								// UART offline
	r4  = 6;
	dm(CUART0TX) = r4;					// DMA counter
	call (pc, _FillTxBuffer);

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA
uart_bye.end:


uart_D:
	r4  = 8;
	dm(CUART0TX) = r4;					// DMA counter
	call (pc, _FillTxBuffer);

	i4  = _uart_rxbuf + 4;
	i10 = _HexPhaseData;
	r4  = 1;
	call (pc, _ConvertFromHEX);				// sector No.
	call (pc, _ConvertFromHEX);				// offset in sector
	r4  = 512;
	call (pc, _ConvertFromHEX);
	r2  = dm(_HexPhaseData + 0);
	r0  = dm(_HexPhaseData + 1);

	r4  = SECTOR_FOR_ID;
	r4  = r2 - r4;

	r8  = LSHIFT r0 by 9;
	if not SZ jump do_not_erase;

	CCALL (_sectorErase);
	if EQ jump (pc, do_not_erase-1);
	r4  = 0x45;							// 'E' erase error
	dm(_uart_txbuf + 4) = r4;
	jump (pc, uart_D1);
	r2  = dm(_HexPhaseData + 0);
do_not_erase:
	r2  = LSHIFT r2 by 12;				// 4KB/sector
	r2  = BSET r2 by 26;					// BASE ADDR. 0x4000000
	r2  = r2 + r8;
	i4  = r2;
	i2  = _HexPhaseData + 2;
	r8  = 512;

	CCALL (_writeFlash_no_erase);
    dm(_HexPhaseData + 0) = m7;	if EQ jump (pc, uart_D1);
	r4  = 0x57;							// 'W' write error
	dm(_uart_txbuf + 4) = r4;
uart_D1:
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_D.end:


uart_P:									// Program Data Set(for current program)
	r4  = 6;
	dm(CUART0TX) = r4;					// DMA counter
	call (pc, _FillTxBuffer);

	i12 = _uart_rxbuf + 4;
	call (pc, _GetNumberFromUart);		// Channel No.(R0)

	i4  = _uart_rxbuf + 6;
	i10 = _HexPhaseData;
	r8  = 0x55;
	pm(i10, m14) = r8;
	r8  = 0xAA;
	r1  = PASS r0, pm(i10, m14) = r8;
	r4  = 2*N_OCTAVE;
	call (pc, _ConvertFromHEX);
	
	call (pc, _smoothPhase);			// r0=channel, unchanged in this func.
	r4  = r1;
	call (pc, _calculateFIR);			// r4=channel

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA
uart_P.end:

uart_S:
	r4  = 5;
	dm(CUART0TX) = r4;					// DMA counter
	call (pc, _FillTxBuffer);

	i12 = _uart_rxbuf + 4;
	call (pc, _GetNumberFromUart);		// flash sector No.

	r4  = dm(_HexPhaseData + 0);
	r8  = dm(_HexPhaseData + 1);
	r8  = r8 OR FDEP r4 by 8:8;
	r4  = 0x55AA;
	COMP (r8, r4);
	if EQ jump (pc, validS), r4 = PASS r0;
	r0  = 0x3;							// 3=flash data format err
	jump (pc, invalidS);
validS:
	i2  = _HexPhaseData;
	r8  = 2*N_OCTAVE + 2;
	CCALL (_writeFlash);
	r4  = 0x30;							// '0'
invalidS:
	r4  = r4 + r0;
	dm(_uart_txbuf + 4) = r4;
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA
uart_S.end:

uart_L:
	r4  = 5;
	dm(CUART0TX) = r4;					// DMA counter
	call (pc, _FillTxBuffer);

	i12 = _uart_rxbuf + 4;
	call (pc, _GetNumberFromUart);		// get flash No.(returned in R0)

	i12 = _uart_rxbuf + 6;
	r2  = PASS r0;
	call (pc, _GetNumberFromUart);		// get channel (returned in R0)

	r4  = PASS r2;						// r4=flash No. r0=channel No.
	call (pc, _loadFromFlash);
	r4  = 0x30;							// '0'
	if NE jump (pc, 3), r4 = r4 + 1;			// invalid flash data
	r4 = r0;
	call (pc, _calculateFIR);
	r4  = 0x30;
	dm(_uart_txbuf + 4) = r4;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA
uart_L.end:


