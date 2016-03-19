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

.extern _programNo;
.extern _programValid;
.extern _programRecallLock;
.extern _programProtection;
.extern _programOutputStatus;
.extern _programName;
.extern _programInfomation;

.extern _sourceSelect;
.extern _generatorSelect;
.extern _pinkNoiseLevel;
.extern _sineFrequency;
.extern _sineLevel;
.extern _generatorMuting;
.extern _InputSelect;
.extern _EQMode;
.extern _GEQLink;
.extern _GEQOnOff;
.extern _GEQParameter;
.extern _GEQLevel;
.extern _PEQLink;
.extern _PEQOnOff;
.extern _PEQParameter;

.extern _PEQLevel;
.extern _compLinkMode;
.extern _compOnOff;
.extern _compEQ;
.extern _compAttack;
.extern _compRelease;
.extern _compThreshold;
.extern _compRatio;
.extern _compGain;
.extern _masterDelay;
.extern _outputChannel;
.extern _tempUserData;

.extern _expf, _exp_dB, _logf, _div10;
.extern _panelCommandTable;
.extern _sineFreq, _sineLvl, _noiseLvl;
.extern _inputSource;
.extern _readFlash, _writeFlash, _sectorErase, _programCheck;
.extern _writeFlash_no_erase;
.extern TCB_Block_ADCx, _samples;

.extern _parametersInit;
.extern _Company, _DeviceInfo, _SoftwareVersion;
.extern _remoteID, _panelStatus;
.extern _switchInterval;
.extern _uart_rxbuf, _uart_txbuf;

.extern _inPower, _outPower, _inpParam, _outpParam;
.extern _digitDisplay00;
.extern _statusUpdate;

.section/dm seg_dmda;
.global _rcvCounter;
.var _rcvCounter = 0;
.var _lockStatusChanged = 0;

.var UartCommandTable[] =
	'V', 7, uart_V,				// (IDVxxx, for verify
	'Z', 7, uart_Z,				// (IDZ, send ADC samples
	'D', 1024+8, uart_D,		// (IDD, flash program, sector+part+512bytes
	'h', 8, uart_hello,			// (IDhello, PC connect
	'b', 6, uart_bye,			// (IDbye, PC disconnect
	'C', 5, uart_C,				// (IDCE or (IDCD, panel lock set
	'K', 4, uart_K,				// (IDK, panel lock check
	'X', 4, uart_X,				// (IDX, device info request
	'Y', @_DeviceInfo+4, uart_Y,// (IDY, device info send
	'A', 4, uart_A,				// (IDA, version check
	'N', 4, uart_N,				// (IDN, Update Check
	'R', 7, uart_R,				// (IDRxxx, Program Recall
	'S', 7, uart_S,				// (IDSxxx, Program Store to FLASH
	'G', 7, uart_G,				// (IDG, Program Delete Command
	'Q', 7, uart_Q,				// (IDQ, Program Data Request Command
	'P', 1022, uart_P,			// (IDP, Program Data Set Command
	'I', 7, uart_I,				// (IDI, Program Information Data Request
	'J', 29, uart_J,			// (IDJ, Program Information Data Set
	'L', 8, uart_L,				// (IDLE or (IDLD, Recall Lock Enable/Disable
	'W', 8, uart_W,				// (IDWE or (IDWD, Protect Enable/Disable
	'M', 5, uart_M,				// (IDME, Level Information Start/Stop
	'%', 8, uart_Perc,			// .(ID%xxxx, Program Parameter Value Request
	'$', 10, uart_$;			// .(ID$xxxxxx, at least 10

.var UartParameterTable[] =		// derived from (ID$
	7, 11, P007 + 1,			// Input Select(?)--CH source in P040
	1, 11, P001,				// Source select(input or generator)
	2, 11, P002,				// Generator select(pink or sinewave)
	3, 11, P003,				// .pink noise level
	4, 11, P004,				// sine frequency
	5, 11, P005,				// sine level
	6, 11, P006,				// generator mute
	10, 10, P010,				// .EQ Mode (PEQ or GEQ? UNKNOWN, unused)
	11, 11, P011,				// .GEQ Link
	12, 13, P012,				// .GEQ Parameter
	13, 11, P013,				// .GEQ Level
	14, 11, P014,				// .GEQ On/Off
	20, 11, P020,				// PEQ link
	21, 22, P021,				// PEQ Parameter Type
	22, 13, P022,				// PEQ Parameter Freq
	23, 13, P023,				// PEQ Parameter Level
	24, 13, P024,				// PEQ Parameter Q
	25, 11, P025,				// PEQ Level
	26, 11, P026,				// PEQ On/Off
	37, 10, P037,				// Comp Link Mode
	27, 11, P027,				// Comp On/Off
	32, 11, P032,				// Comp Attack
	33, 11, P033,				// Comp Release
	34, 11, P034,				// Comp Threshold
	35, 11, P035,				// Comp Ratio
	36, 11, P036,				// Comp Gain
	28, 20, P028,				// .Compressor Side EQ Type
	29, 11, P029,				// .Compressor Side EQ Freq
	30, 11, P030,				// .Compressor Side EQ Level
	31, 11, P031,				// .Compressor Side EQ Q
	38, 14, P038,				// Master Delay
	54, 22, P054,				// CH Link
	40, 11, P040,				// CH Source
	41, 11, P041,				// Crossover LCF Type
	42, 11, P042,				// Crossover LCF Freq
	43, 11, P043,				// Crossover HCF Type
	44, 11, P044,				// Crossover HCF Freq
	45, 22, P045,				// CH PEQ Type,Freq,Level,Q
	46, 13, P046,				// CH PEQ Freq
	47, 13, P047,				// CH PEQ Level
	48, 13, P048,				// CH PEQ Q
	49, 11, P049,				// CH Level
	50, 11, P050,				// Peak Limiter Threshold
	51, 14, P051,				// CH Delay
	52, 11, P052,				// CH Phase
	53, 11, P053;				// CH Muting

.section/pm seg_pmco1;

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
	r0=0x42;
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
	Function: get one data from contiuous uart buffer(convert ASCII to digits)
	Import: i4: uart buffer data related start address,
			r8: the byte numbers in uart buffer needed to convert
	Changed Register: r0, r1, r4
	Export: r0;
*/
_GetNumberFromUart:
	r4 = 0x30;							// '0'
	bit SET ustat4 BIT_14;				// set ERROR bit, overRange[0~9]

	r0 = r0 - r0, puts = r10;
	r10 = 10;
	lcntr = r8, do GetNumberFromUart0 until lce;
		r0 = r0 * r10(UUI), r1 = dm(i4, m6);
		r1 = r1 - r4;					// convert ASCII to digit
		if LT jump (pc, Number_Error)(LA), else comp(r1, r10);	// x<0
		if GE jump (pc, Number_Error)(LA), else r0 = r0 + r1;	// x>9
		nop;
		nop;
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


/************************************************************************
 * convert level to dB scale and add 90dB in ASCII, ie. -15dB->'075'
 * log10(x) = 0.4342944819*ln(x)-->
 * 10*log10(x) = 4.342944819*ln(x)
 ************************************************************************/
_getLevelInformation:
	i2 = _inPower;
	i10 = _uart_txbuf + 4;
	r9 = 100;							// 100dB
	r3 = 10;							// dB' = dB + (100 - 10)
	r10 = 0x30;							// ASCII('0')
	f4 = dm(i2, m6);					// 0<=f4<1
	f6 = 4.3429448190325182765;			// 10*log10(e)
	lcntr = INS + OUTS, do (pc, _level1) until lce;
		CCALL (_logf);

		f0 = f0 * f6, r12 = r10;
		r8 = FIX f0;
		r8 = r8 - r3;					// >=100dB?
		if GE jump (pc, 3), r12 = r12 + 1;
		r8 = r8 + r9;
		if LE r8 = r8 - r8;				// negative, set to 000
		CCALL (_div10);
		r0 = r0 + r10, pm(i10, m14) = r12;
		r8 = r8 + r10, pm(i10, m14) = r0;
_level1:
		f4 = dm(i2, m6), pm(i10, m14) = r8;

	r0 = 0x3f;							// '?';
	lcntr = 18, do (pc, 1) until lce;
		pm(i10, m14) = r0;

	i4 = _outpParam + 5;
	m4 = 6;
	r4 = dm(i4, m4);						// r8=1 means compressed
	r8 = r4 + r10, r4 = dm(i4, m4);
	lcntr = OUTS, do (pc, 1) until lce;
		r8 = r4 + r10, r4 = dm(i4, m4), pm(i10, m14) = r8;

	rts;

_getLevelInformation.end:


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

	r4 = dm(_uart_rxbuf);
	r10 = 0x28;							// '(' Ensure a start BYTE
	comp (r4, r10);						// bug in new board
	if NE jump (pc, exitUART);

	call (pc, _GetNumberFromUart)(DB);	// get ID from uart_rxbuf
	i4 = _uart_rxbuf + 1;
	r8 = 2;

	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;

	r4 = dm(_remoteID);
	comp (r0, r4), r9 = dm(i4, m6);		// is these data for me?
	if NE jump (pc, exitUART);			// not for me

	i5 = UartCommandTable;				// r9=letters or $
	lcntr = @UartCommandTable/3, do (pc, checkValid) until lce;
		r10 = dm(i5, m6);
		comp(r9, r10), r10 = dm(i5, m6);
		if NE jump (pc, checkValid), else comp(r12, r10);
		if GE jump (pc, checkValidMatch)(LA);
		nop;
		nop;
		nop;
checkValid:
		modify(i5, m6);

exitUART:
	rts;

checkValidMatch:
	i12 = dm(i5, m5);
	dm(UART0TXCTL) = m5;				// disable DMA
	jump (m13, i12)(DB);
	r0 = _uart_txbuf;
	dm(IIUART0TX) = r0;					// DMA index register
_setNewParameters.end:

/*
	Function: send uart tx buffer to PC
	Import:	 R4(tx buffer 's length:byte numbers)
	Changed registers: r8, i4, i10
	Export: No
*/
_FillTxBuffer:
	i4 = _uart_rxbuf;
	i10 = _uart_txbuf;

	r8 = dm(i4, m6);
	lcntr = r4, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	rts;
_FillTxBuffer.end:

/*
	Function: Filling the error code(in R4) into uart tx buffer
	Import: R4:error code(0x??):0x00~0x30
	Export: No;
*/
_uart_error_process:
	i4 = _uart_txbuf + 3;
	r8 = 0x65;							// 'e' stands for "error"

	r0 = FEXT r4 by 8:8, dm(i4, m6) = r8;
	r0 = FEXT r4 by 0:8, dm(i4, m6) = r0;
	r4 = FEXT r8 by 4:4, dm(i4, m6) = r0;	// BIT4-7 of r8 is 6(coincidentally)

	dm(CUART0TX) = r4;					// DMA counter
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;			// Enable DMA
	dm(UART0TXCTL) = ustat1;
_uart_error_process.end:


/*
	Function: check the correct band
	max. band numbers to be checked in r14(import)
	return: r14(band number)
*/
_bandCheck:
	call _GetNumberFromUart(DB);		// get band number
	i4 = _uart_rxbuf + 8;
	r8 = 2;
	bit TST ustat4 BIT_14;
	if TF rts;

	r14 = pass r0, r0 = r14;
	if LT jump (pc, 2), else comp(r14, r0);
	if LE rts;							// no error
	rts(DB);
	bit set ustat4 BIT_14;				// set error FLAG
	r4 = 0x3232;						// errno = "22"
_bandCheck.end:


/*
	Function:	Pick-up program no from uart rx buffer
	format : (IDAxxx....., convert xxx to a value from 000 to 050
	Import: No
	Changed register:R0;
	Export:R0(program no,00~50), return when error
*/
_PickUpProgramNoFromUartBuf:
	call (pc, _GetNumberFromUart)(DB);
	i4 = _uart_rxbuf + 4;
	r8 = 3;

	bit TST ustat4 BIT_14;
	if TF rts;
	r0 = pass r0;
	r4 = 50;
	if LT jump (pc, pickErrorNo), else comp(r0, r4);	// <0
	if GT jump (pc, pickErrorNo);		// programNo>50

	rts;
pickErrorNo:
	rts(DB);
	bit SET ustat4 BIT_14;
	r4 = 0x3130;						// errno = "10"
_PickUpProgramNoFromUartBuf.end:

/*
	Function: the program data structure(Except program name and information)
	is converted into the 2-byte ASCII HEX code,ready to send back to the PC
	Import: R4(after convert numbers=2*program byte)
			I4:program data pointer
			I10:uart tx buffer pointer
	Changed Register: I4,I10
	Export:No
*/
_ConvertIntoHEX:

	r7 = 7;
	r9 = 9;
	r10 = 0x30;
	r8 = dm(i4, m6);
	lcntr = r4, do ConvertIntoHEX0 until lce;
		r4 = FEXT r8 by 4:4;			//get high nibble
		comp(r4, r9);
		if GT r4 = r4 + r7;				// 'A'-'F'
		r4 = r4 + r10;
		r4 = FEXT r8 by 0:4, pm(i10, m14) = r4;	//low nibble
		comp(r4, r9);
		if GT r4 = r4 + r7;				// 'A'-'F'
		r4 = r4 + r10;
ConvertIntoHEX0:
		r8 = dm(i4, m6), pm(i10, m14) = r4;

	rts;
_ConvertIntoHEX.end:


/*
	Function: convet 2-bytes ASCII into user program data structure
	Import: R4(numbers)
			I10: user program data pointer(SRAM)
			I4: uart rx buffer pointer
	Changed register: r7, r8, r9, r10, r12
	Export:No
*/
_ConvertFromHEX:

	r7 = 7;
	r9 = 0x39;
	r10 = 0x30;
	r8 = dm(i4, m6);
	lcntr = r4, do ConvertFromHEX0 until lce;
		comp(r8, r9);
		if GT r8 = r8 - r7;				// 'A'-'F'

		r12 = r8 - r10, r8 = dm(i4, m6);
		comp(r8, r9);
		if GT r8 = r8 - r7;				// 'A'-'F'
		r8 = r8 - r10;
		r8 = r8 OR LSHIFT r12 BY 4;
ConvertFromHEX0:
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	rts;
_ConvertFromHEX.end:


uart_hello:								// Communication Check, UART online
	r4 = 8;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;
	dm(_lockStatusChanged) = m5;		// mark lockstatus, avoid unneccessary flash write

	r4 = SWITCH_DELAY;
	dm(_switchInterval) = r4;
	r4 = dm(_panelCommandTable + 0);	// panel status indicators
	r4 = BCLR r4 by 3;					// panel indicator light ON
	bit SET ustat4 BIT_28;				// disable IRQ1(key)
	bit CLR IMASK IRQ1I;
	dm(_panelCommandTable + 0) = r4;	// Restore panel status indicators
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_hello.end:


uart_bye:								// UART offline
	r4 = 6;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;
	
	r4 = dm(_lockStatusChanged);
	r4 = r4 - 1;
	if NE jump uart_bye1;
	i2 = _remoteID;						// Save panel lock status into FLASH
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_writeFlash);
uart_bye1:
	r2 = dm(_panelStatus);				// r2 = panellockstatus
	r4 = dm(_panelCommandTable + 0);	// panel status indicators
	r4 = BCLR r4 by 3 ;
	BTST r2 by 2;						// LOCK bit = 1?
	if not SZ jump (pc, 3);
	r4 = BSET r4 by 3;					// panel indicator light OFF
	bit CLR ustat4 BIT_28;
	dm(_panelStatus) = r2;
	dm(_panelCommandTable + 0) = r4;	// Restore panel status indicators
	
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_bye.end:


uart_C:									// Panel Lock('D') Unlock('E') setting
	r4 = 4;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	r0 = dm(_panelStatus);
	r0 = BSET r0 by 2;					// lock as DEFAULT
	r3 = 0x44;							// 'D'
	r8 = r8 - r3;						// r8=_uart_rxbuf[4]
	dm(_lockStatusChanged) = m6;
	if EQ jump (pc, 2);					// disable panel operation
	r0 = BCLR r0 by 2;					// enable panel operation
	dm(_panelStatus) = r0;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_C.end:


uart_K:									// Panel Status Check(E or D)
	r4 = 4;
	call _FillTxBuffer;
	r4 = 5;
	dm(CUART0TX) = r4;					// DMA counter
	
	r2 = dm(_panelStatus);				// r2 = panellockstatus

	r0 = FEXT r2 by 2:1;				// if BIT2/panelstatus=0 then disabled
	r2 = 0x45;							// 'E'
	r0 = r2 - r0;
	dm(_uart_txbuf + 4) = r0;			// Ack command:(01KE or (01KD
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_K.end:


uart_X:									// Device Information Request
	r4 = 4;
	call _FillTxBuffer;

	i4 = _DeviceInfo;
	r0 = @_DeviceInfo;
uart_X1:
	r8 = dm(i4, m6);					// i10 -> _uart_txbuf + 4;
	lcntr = r0, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	ustat1 = UARTDEN|UARTEN;
	dm(_rcvCounter) = m5;
	rts(DB), r4 = r4 + r0;
	dm(CUART0TX) = r4;					// DMA counter
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_X.end:


uart_Y:									// Device Information Set
	r4 = 4;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	i10 = _DeviceInfo;					// r8 = uart_rxbuf[4];
	lcntr = @_DeviceInfo, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	r4 = r4 - r4;
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_writeFlash);				// R4=0,save machine info

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA
uart_Y.end:

uart_A:									// Software version Check
	r4 = 4;
	call _FillTxBuffer;

	i4 = _SoftwareVersion;
	r0 = @_SoftwareVersion;

	jump uart_X1;

uart_A.end:


uart_N:									// Current Program Update Check
	r4 = 4;
	call _FillTxBuffer;
	r8 = 0x43;							// 'C' stands for 'Checking...'
	dm(_uart_txbuf + 4) = r8;

	ustat1 = UARTDEN|UARTEN;
	dm(_rcvCounter) = m5;
	rts(DB), r4 = r4 + 1;
	dm(CUART0TX) = r4;					// DMA counter
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_N.end:


uart_R:									// Program Recall
//	The recall command is able to access the recall-locked program, which
//	is inaccessible via the front-panel buttons.

	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;	// get program No. in R0
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;

	r4 = pass r0, r0 = m6;				// if R0!=0 then check programvalid
	if LE jump recall_no_need;

	CCALL (_programCheck);
	r2 = pass r2, r3 = r4;
	r4 = 0x3131;
	if NE jump _uart_error_process;		// given sector contains no valid data
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	r4 = PASS r3,
	CCALL (_readFlash);

	r4 = 51;
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);

	call _parametersInit;
recall_no_need:
	dm(_rcvCounter) = m5;
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

	r8 = dm(_programNo);
	jump (pc, _digitDisplay00);			// update panel digits and return

uart_R.end:


uart_S:									// Program Store
	// Specify a 3-digit program number between 002 and 050.
	// 001 is also accessable(unlike SRP-F300) as well as 002-050
	// 000 will find a youngest unused number to overwrite

	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;

	r4 = pass r0, r3 = r0;
	if GT jump (pc, uart_S2), else r4 = r4 + 1;	// program No>=1

	r0 = PROG_VALID;				// check program valid
	lcntr = 50, do uart_S1 until lce;	// search  unused number from bottom
		CCALL (_programCheck);
		r2 = pass r2;					// non-protected sector found
uart_S1:
		if NE jump (pc, uart_S3)(LA), else r4 = r4 + 1;

	r4 = 0x3132;						// errno = "12"
	jump _uart_error_process;			// Memory overflow

uart_S2:
	r0 = PROG_PROT;						// check program Protection
	CCALL (_programCheck);				// check specified program
	r2 = pass r2;
	r4 = 0x3133;						// protected, return '13'
	if EQ jump _uart_error_process;		// program protected

	r4 = r3;
uart_S3:
	dm(_programNo) = r4;
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);

	r4 = 51;
	i2 = _programNo;
	CCALL (_writeFlash);

	r8 = dm(_programNo);
	CCALL (_div10);						// (r0,r8)=r8/10

	i4 = _uart_txbuf + 4;
	r2 = 0x30;				// '0'
	r0 = r0 + r2, dm(i4, m6) = r2;		// result.quot
	r8 = r8 + r2, dm(i4, m6) = r0;		// result.rem
	dm(i4, m6) = r8;

	dm(_rcvCounter) = m5;
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

	r8 = dm(_programNo);
	jump (pc, _digitDisplay00);			// update panel digits and return

uart_S.end:


uart_G:									// Program Delete
	// Specify a 3-digit program number between 001 and 050.

	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;
	r4 = 0x3131;
	r3 = pass r0;
	if LE jump _uart_error_process;		// 000 return "11"

	r0 = 3;								// program Protection
	r4 = PASS r3,
	CCALL (_programCheck);
	r2 = pass r2;
	r4 = 0x3132;						// errno = "12"
	if EQ jump _uart_error_process;		// program is protected

	r4 = PASS r3,
	CCALL (_sectorErase);

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_G.end:


uart_Q:									// Program Data Request
	r4 = 7;
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;

	i4 = _programNo;					// Current program
	r4 = pass r0, r0 = m6;
	if EQ jump uart_Q1;					// '000' for CURRENT program
	CCALL (_programCheck);				// i4->point to program(r4)
	r2 = pass r2;
	r4 = 0x3130;
	if NE jump _uart_error_process;
uart_Q1:
	r4 = 1030;
	dm(CUART0TX) = r4;					// DMA counter

//	i10 = _uart_txbuf + 7;

	r8 = 0x31;							//'1'
	pm(i10, m14) = r8;
	r8 = 0x30;							//'0'
	pm(i10, m14) = r8;
	r8 = 0x31;							//'1'
	pm(i10, m14) = r8;
	r8 = 0x39;							//'9'
	pm(i10, m14) = r8;

	r4 = 10;
	call _ConvertIntoHEX;

	lcntr = 277, do (pc, 1) until lce;	// copy ASCII strings(21+256)
		r8 = dm(i4, m6), pm(i10, m14) = r8;
	modify(i4, m7);

	r4 = 361;
	call _ConvertIntoHEX;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_Q.end:


uart_V:									// memory verify
	call (pc, _GetNumberFromUart)(DB);
	i4 = _uart_rxbuf + 4;
	r8 = 3;

	i4 = _programNo;					// Current program
	r4 = pass r0, r0 = m5;
	if EQ jump uart_V1;					// '000' for CURRENT program
	CCALL (_programCheck);				// i4->point to program(r4)
uart_V1:
	r4 = 1024;
	dm(CUART0TX) = r4;					// DMA counter

	i10 = _uart_txbuf;

	r8 = dm(i4, m6);					// copy ASCII strings(21+256)
	lcntr = r4, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_V.end:


uart_Z:									// send ADC samples in HEX
	r4 = 7;
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;   // get offset from _samples in R0

	r4 = _samples;
	r4 = r4 + r0;
	i4 = r4;
	i10 = _uart_txbuf;
    r7 = 7;
    r9 = 9;
    r10 = 0x30;
	lcntr = 8, do uart_Z1 until lce;
		r8 = dm(i4, m6);
		lcntr = 8, do uart_Z2 until lce;
			r4 = FEXT r8 by 28:4;
			comp(r4, r9);
			if GT r4 = r4 + r7;			// 'A'-'F'
			r4 = r4 + r10;
uart_Z2:
			r8 = LSHIFT r8 by 4, pm(i10, m14) = r4;
uart_Z1:
		nop;

	r4 = 64;
	dm(CUART0TX) = r4;
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_Z.end:


uart_D:
	r4 = 8;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	i4 = _uart_rxbuf + 4;
	i10 = _tempUserData;
	r4 = 1;
	call _ConvertFromHEX;				// sector No.
	modify(i4, m7);
	call _ConvertFromHEX;				// offset in sector
	modify(i4, m7);
	r4 = 512;
	call _ConvertFromHEX;
	r2 = dm(_tempUserData + 0);
	r0 = dm(_tempUserData + 1);

	r4 = SECTOR_FOR_ID;
	r4 = r2 - r4;

	r8 = LSHIFT r0 by 9;
	if not SZ jump do_not_erase;

	CCALL (_sectorErase);

do_not_erase:
	r2 = dm(_tempUserData + 0);
	r2 = LSHIFT r2 by 12;				// 4KB/sector
	r2 = BSET r2 by 26;					// BASE ADDR. 0x4000000
	r2 = r2 + r8;
	i4 = r2;
	i2 = _tempUserData + 2;
	r8 = 512;

	CCALL (_writeFlash_no_erase);

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_D.end:


uart_P:									// Program Data Set(for current program)
	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

/*
	Function: Check if all bytes are in range of [0x20,0x7d]
	Import: R4(byte numbers)
	Altered Registers:R0,R1,R2,R4
	Export:R4 ,error code "30"
*/
_CheckUartBuffer:
	i4 = _uart_rxbuf + 7 + 2*(1+1+6) + 21 + 256;
	r1 = 0x20;
	r2 = 0x7d;
	r4 = 0x3330;						// error code
	r0 = dm(i4, m6);
	lcntr = 1022-7-2*(1+1+6)-21-256, do CheckUartBuffer0 until lce;
		comp(r0, r1);					// < 0x20
		if LT jump (pc, _uart_error_process)(LA);
		comp(r0, r2);					// > 0x7d
		if GT jump (pc, _uart_error_process)(LA);
		r0 = dm(i4, m6);
		nop;
		nop;
CheckUartBuffer0:
		nop;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	IF TF jump _uart_error_process;		// set current program

	i10 = _programRecallLock;			// skip ProgamNumber and ProgramValid
	i4 = _uart_rxbuf + 7;
	r4 = 8;
	call _ConvertFromHEX;

	lcntr = 277, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;
	modify(i4, m7);

	r4 = 361;
	call _ConvertFromHEX;

	call _parametersInit;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_P.end:


uart_I:									// Program Information Data Request
	r4 = 7;
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;

	i4 = _programNo;
	r4 = pass r0, r0 = m6;				// programValid?
	if EQ jump uart_I1;

	CCALL (_programCheck);				// i4->point to requested program
	r2 = pass r2;
	r4 = 0x3131;						// specified program is invalid
	if NE jump _uart_error_process;

uart_I1:
	r4 = 308;
	dm(CUART0TX) = r4;					// DMA counter

//	i10 = _uart_txbuf + 7;				// i4->point to requested program

	r8 = 0x30;							//'0'
	pm(i10, m14) = r8;
	r8 = 0x32;							//'2'
	pm(i10, m14) = r8;
	r8 = 0x39;							//'9'
	pm(i10, m14) = r8;
	r8 = 0x37;							//'7'
	pm(i10, m14) = r8;

	r4 = 10;
	call _ConvertIntoHEX;

	lcntr = 277, do (pc, 1) until lce;
		r8 = dm(i4, m6), pm(i10, m14) = r8;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_I.end:


uart_J:									// Program Information Data Set
	r4 = 8;
	dm(CUART0TX) = r4;
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	IF TF jump _uart_error_process;

	i4 = _uart_rxbuf + 7;
	r3 = pass r0, r4 = dm(i4, m6);
	r0 = 0x32;
	comp (r4, r0);						// r4 = '2'
	if NE jump (pc, uart_J1), r0 = r0 + 1;

	jump (pc, uart_J2)(DB);
	i10 = _programName;
	r6 = @_programName;

uart_J1:
	comp (r4, r0);						// r4 = '3'
	if NE rts;

	r10 = 264;
	comp (r12, r10);
	if LT rts;
	i10 = _programInfomation;
	r6 = @_programInfomation;

uart_J2:

	r4 = dm(i4, m6);
	lcntr = r6, do (pc, 1) until lce;
		r4 = dm(i4, m6), pm(i10, m14) = r4;

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_J.end:


uart_L:					// Program Recall Lock Change(E or D)
	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;		// invalid program No.

	r4 = pass r0, r3 = r0;
	if LE jump _uart_error_process;		// 000 invalid
	i2 = _tempUserData;
	r8 = _tempUserData - _programNo;
	CCALL (_readFlash);

	r2 = dm(_uart_rxbuf + 7);
	r0 = 0x45;							// 'E': recall Enabled
	r2 = r2 - r0, r4 = r3;
	dm(_tempUserData + 2) = r2;			// RecallLock
	i2 = _tempUserData;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_L.end:


uart_W:									// Prog. Protect Setting Change(E or D)
	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	call _PickUpProgramNoFromUartBuf;
	bit TST ustat4 BIT_14;
	if TF jump _uart_error_process;		// invalid program No.

	r4 = pass r0, r3 = r0;
	if LE jump _uart_error_process;		// 000 invalid
	i2 = _tempUserData;
	r8 = _tempUserData - _programNo;
	CCALL (_readFlash);

	r2 = dm(_uart_rxbuf + 7);
	r0 = 0x44;							// 'D': protection Enabled
	r2 = r0 - r2, r4 = r3;
	dm(_tempUserData + 3) = r2;			// protection
	i2 = _tempUserData;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);

	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_W.end:


uart_M:									// Level Information Start/Stop
	r4 = 4;
	call _FillTxBuffer;

	r3 = 0x45;							// 'E'
	comp (r8, r3);						// r8=_uart_rxbuf[4];
	if NE jump (pc, 3);
	call _getLevelInformation;
	r4 = 52;
	dm(CUART0TX) = r4;					// DMA counter
	dm(_rcvCounter) = m5;
	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

uart_M.end:


uart_Perc:			//Current Program Parameter Value Request Command??
	r4 = 10;
	call _FillTxBuffer;
		//Fill Parameter Value...
	dm(_rcvCounter) = m5;
	rts;
uart_Perc.end:

/*********************************************************************
 * Program Parameter Value Change Command???...
 * get value from uart buffer 4,5,6 in R0
 ********************************************************************/
uart_$:
	call _GetNumberFromUart(DB);
	r8 = 3;
	i5 = UartParameterTable;			//find the index from $-jump table

//	r12 = dm(_rcvCounter);
	lcntr = @UartParameterTable/3, do uart_0 until lce;
		r8 = dm(i5, m6);
		comp(r0, r8), r10 = dm(i5, m6);
		if NE jump (pc, uart_0), else comp(r12, r10);
		if GE jump (pc, uart_1)(LA);
		nop;
uart_0:
		modify(i5, m6);

	rts;								// parameters not matched

uart_1:
	r0 = 0x30;							// '0'--ASCII
	r12 = dm(i4, m6);					// i4 -> _uart_rxbuf + 7
	r12 = r12 - r0, i12 = dm(i5, m5);	// r12=channel
	dm(UART0TXCTL) = m5;				// disable DMA
	dm(_rcvCounter) = m5;
	jump (m13, i12)(DB);
	r0 = _uart_txbuf;
	dm(IIUART0TX) = r0;					// DMA index register

uart_$.end:

P007:		//(ID$007CVVV, Input Select
P007_L0:
	call _parametersInit;
	call _statusUpdate;
	r4 = 7;
	dm(CUART0TX) = r4;					// DMA counter
	call _FillTxBuffer;

	rts(DB);
	ustat1 = UARTDEN|UARTEN;
	dm(UART0TXCTL) = ustat1;			// Enable DMA

P001:		//(ID$001CVVV, Source select: analog(0) or generator(1)
	r8 = 3;
	call _GetNumberFromUart;
	dm(_sourceSelect) = r0;				// zero and non-zero

	i2 = _inputSource;
	r0 = PASS r0;
	if EQ jump (pc, P001_L2);
	r0 = dm(_generatorSelect);
	r0 = PASS r0;
	if NE r0 = m6;
	r0 = r0 + 1;
P001_L2:
	r12 = r12 - 1;
	if LT jump (pc, P001_L1);
	
	jump (pc, P007_L0 + 2)(DB);			// skip parameters init
	m4 = r12;
	dm(m4, i2) = r0;
P001_L1:
	jump (pc, P007_L0 + 2)(DB);
	dm(i2, m6) = r0;
	dm(i2, m6) = r0;

P002:		//(ID$002CVVV, pink(0) or sine(1) select
	r8 = 3;
	call _GetNumberFromUart;
	r0 = PASS r0;
	if NE r0 = m6;
	dm(_generatorSelect) = r0;			// only 0 and 1 available

	jump (pc, P007_L0 + 2);				// skip parameters init

P003:		//(ID$003CVVV, pink level
	r8 = 3;
	call _GetNumberFromUart;			// level(dB)
	dm(_pinkNoiseLevel) = r0;
	i2 = _noiseLvl;
	jump (pc, P005_L1);

P004:		//(ID$004CVVV, Sine frequency
	r8 = 3;
	call _GetNumberFromUart;			// r0 = Frequency index(1~121)
	dm(_sineFrequency) = r0;

	r0 = PASS r0;
	if EQ jump (pc, P007_L0 + 2);		// freq=0, do NOTHING

	f4 = FLOAT r0, puts = r12;
	f12 = 0.0577622650466621;			// ln(2)/12
	CCALL (_exp_dB + 1);
	f2 = 18.65 * MAXBUFFER / FS;		// freq=20*10^(i/12)
	f4 = f0 * f2, r12 = gets(1);
	r0 = FIX f4;

	i2 = _sineFreq;
	r12 = r12 - 1, alter(m6);
	if LT jump (pc, P004_L1);
	jump (pc, P007_L0 + 2)(DB);			// skip parameters init
	m4 = r12;
	dm(m4, i2) = r0;
P004_L1:
	jump (pc, P007_L0 + 2)(DB);			// skip parameters init;
	dm(i2, m6) = r0;
	dm(i2, m6) = r0;

P005:		//(ID$005CVVV, sine level
	r8 = 3;
	call _GetNumberFromUart;			// level(dB)
	dm(_sineLevel) = r0;

	i2 = _sineLvl;

P005_L1:
	r4 = 181;
	r4 = r0 - r4, puts = r12;
	f4 = FLOAT r4,
	CCALL (_exp_dB);

	r1 = dm(_generatorMuting);
	f1 = FLOAT r1;
	f0 = f0 * f1, r12 = gets(1);
	r12 = r12 - 1, alter(m6);			// replace alter(1)
	if LT jump (pc, P005_L2);
	jump (pc, P007_L0 + 2)(DB);			// skip parameters init
	m4 = r12;
	dm(m4, i2) = f0;
P005_L2:
	jump (pc, P007_L0 + 2)(DB);			// skip parameters init
	dm(i2, m6) = f0;
	dm(i2, m6) = f0;

P006:		//(ID$006CVVV, generator mute
	r8 = 3;
	call _GetNumberFromUart;			// 000(mute)
	dm(_generatorMuting) = r0;

	jump (pc, P007_L0 + 2);

P010:									// EQ Mode
P011:									// GEQ Link
P012:									// GEQ Parameter
P013:									// GEQ Level
P014:									// GEQ OnOff

P028:									// Compressor Side EQ Type
P029:									// Compressor Side EQ Freq
P030:									// Compressor Side EQ Level
P031:jump (pc, P007_L0 + 2);			// Compressor Side EQ Q
P032:		//(ID$032CVVV, Compressor Attack
	i2 = _compAttack;
	jump P036 + 1;

P033:		//(ID$033CVVV, Comp Release
	jump (pc, P036 + 2)(DB);
	i2 = _compRelease;
	r8 = 3;

P034:		//(ID$034CVVV, Compressor Threshold
	jump (pc, P036 + 2)(DB);
	i2 = _compThreshold;
	r8 = 3;

P035:		//(ID$035CVVV, Compressor Ratio
	jump (pc, P036 + 2)(DB);
	i2 = _compRatio;
	r8 = 3;

P036:		//(ID$036CVVV, Compressor Gain
	i2 = _compGain;

	r8 = 3;								// i4 -> _uart_rxbuf + 8;
	call _GetNumberFromUart;

	r12 = r12 - 1;
	if LT jump (pc, 4);
	jump (pc, P007_L0)(DB);
	m4 = r12;
	dm(m4, i2) = r0;
	jump (pc, P007_L0)(DB);
	dm(i2, m6) = r0;
	dm(i2, m6) = r0;

P020:		//(ID$020CVVV, PEQ Link
	r8 = 3;								// i4 -> _uart_rxbuf + 8;
	call _GetNumberFromUart;			// get PEQ Link value

	dm(_PEQLink) = r0;
	r0 = pass r0;
	if EQ jump (pc, P007_L0 + 2);		// OFF-link, do nothing

	//link is switched OFF to ON,copy specified channel parameters to all
	r4 = 0x3232;
	r2 = _PEQParameter;
	r0 = _PEQParameter + IN_PEQS*4;
	r12 = r12 - 1;
	if LT jump (pc, P007_L0 + 2);		// Link to 0? No!
	if EQ r2 = pass r0, r0 = r2;
	i4 = r0;
	i10 = r2;

	r2 = INS;
	comp(r12, r2);
	if GE jump _uart_error_process;     // channel > INS? error!
	m4 = r12;
	i2 = _PEQOnOff;
	r4 = dm(m4, i2);                    // copy _PEQOnOff to all channels
	dm(i2, m6) = r4;
	dm(i2, m6) = r4;

	i2 = _PEQLevel;
	r4 = dm(m4, i2);                    // copy _PEQLevel to all channels
	dm(i2, m6) = r4;
	dm(i2, m6) = r4;

	r4 = dm(i4, m6);					// copy PEQParameters
	lcntr = IN_PEQS * 4, do (pc, 1) until lce;
		r4 = dm(i4, m6), pm(i10, m14) = r4;

	jump (pc, P007_L0);

P021:		//(ID$021CBBTTTFFFLLLQQQ, PEQ Parameter Type,Freq,Level,Q
	r14 = IN_PEQS - 1;					// band 0 ~ 10 possible
	call _bandCheck;
	bit tst ustat4 BIT_14;
	if TF jump _uart_error_process;

	r14 = r14 + r14;					// 2 channels
	i2 = _PEQParameter;

	r12 = r12 - 1, r13 = r14;
	if LT jump (pc, 3), r13 = r14 + 1;	// linkStatus, set both channels
	r13 = r14 + r12;
	r14 = r14 + r12;
	r13 = LSHIFT r13 by 2;
	r14 = LSHIFT r14 by 2;				// 4 bytes
	m2 = r14;
	m3 = r13;

	r8 = 3;								// i4 -> _uart_rxbuf + 10;
	call _GetNumberFromUart;			// Type(000--005)
	dm(m2, i2) = r0;
	dm(m3, i2) = r0;
	modify(i2, m6);
	call _GetNumberFromUart;			// Freq(001--121)
	dm(m2, i2) = r0;
	dm(m3, i2) = r0;
	modify(i2, m6);
	call _GetNumberFromUart;			// Level(000-048)
	dm(m2, i2) = r0;
	dm(m3, i2) = r0;
	modify(i2, m6);
	call _GetNumberFromUart;			// Q(000-072)
	dm(m2, i2) = r0;
	dm(m3, i2) = r0;

	jump (pc, P007_L0);

P022:		//(ID$022CBBVVV, PEQ Parameter Freq
	i2 = _PEQParameter + 1;
	jump P024 + 1;

P023:		//(ID$023CBBVVV, PEQ Parameter Level
	i2 = _PEQParameter + 2;
	jump P024 + 1;

P024:		//(ID$024CBBVVV, PEQ Parameter Q
	i2 = _PEQParameter + 3;

	r14 = IN_PEQS - 1;					// band 0 ~ 10 possible
	call _bandCheck;
	bit tst ustat4 BIT_14;
	if TF jump _uart_error_process;
	r14 = r14 + r14;					// 2 channels

	r12 = r12 - 1, r13 = r14;
	if LT jump (pc, 3), r13 = r14 + 1;	// LinkStatus, set all channels
	r13 = r14 + r12;
	r14 = r14 + r12;
	r13 = LSHIFT r13 by 2;
	r14 = LSHIFT r14 by 2;				// 4 bytes
	m2 = r14;
	m3 = r13;

	r8 = 3;								// i4 -> _uart_rxbuf + 10;
	call _GetNumberFromUart;			// get Type,Freq,Level or Q in R0
	dm(m2, i2) = r0;
	dm(m3, i2) = r0;

	jump (pc, P007_L0);

P025:		//(ID$025CVVV, PEQ Level
	jump (pc, P036 + 2)(DB);
	i2 = _PEQLevel;
	r8 = 3;

P026:		//(ID$026CVVV, input PEQ OnOff
	jump (pc, P036 + 2)(DB);
	i2 = _PEQOnOff;
	r8 = 3;

P037:		//(ID$037VVV, Comp Link Mode, 000-no link, 001-003 link
	i4 = _uart_rxbuf + 7;
	r8 = 3;
	call _GetNumberFromUart;

	dm(_compLinkMode) = r0;
	jump (pc, P007_L0);

P027:		//(ID$027CVVV, ÊäÈë¾²Òô(0=mute)
	jump (pc, P036 + 2)(DB);
	i2 = _compOnOff;
	r8 = 3;

P038:		//(ID$038CVVVVVV, Master Delay
	r8 = 6;								// i4 -> _uart_rxbuf + 8;
	call _GetNumberFromUart;			// r0 = delay
	i2 = _masterDelay;

	r12 = r12 - 1;
	if GE jump(pc, P038_L1);			// 8bit x 4 for each delay value
	r4 = FEXT r0 by 24:8;				// MSB first
	r4 = FEXT r0 by 16:8, dm(i2, m6) = r4;
	r4 = FEXT r0 by  8:8, dm(i2, m6) = r4;
	r4 = FEXT r0 by  0:8, dm(i2, m6) = r4;
	r4 = FEXT r0 by 24:8, dm(i2, m6) = r4;
	r4 = FEXT r0 by 16:8, dm(i2, m6) = r4;
	r4 = FEXT r0 by  8:8, dm(i2, m6) = r4;
	r4 = FEXT r0 by  0:8, dm(i2, m6) = r4;
	dm(i2, m6) = r4;
	jump (pc, P007_L0);

P038_L1:
	r12 = LSHIFT r12 by 2;				// 4 bytes for delay value
	m4 = r12;
	r4 = FEXT r0 by 24:8;				// MSB first
	dm(m4, i2) = r4;
	r4 = FEXT r0 by 16:8, r8 = dm(i2, m6);//i2++
	dm(m4, i2) = r4;
	r4 = FEXT r0 by 8:8, r8 = dm(i2, m6);//i2++
	dm(m4, i2) = r4;
	r4 = FEXT r0 by 0:8, r8 = dm(i2, m6);//i2++
	dm(m4, i2) = r4;

	jump (pc, P007_L0);

P054:		//(ID$054VVV VVV VVV VVV VVV, CH Link
	i2 = _outputChannel;
	r12 = 0x01;							// default F link
	r2 = OUTS - 1;

	i4 = _uart_rxbuf + 7;				//data begins at the 7th byte in rxbuf
	r8 = 3;
	lcntr = OUTS - 1, do P054_L0 until lce;
		call _GetNumberFromUart;
		BTST r0 by 0;
		if not SZ r12 = BSET r12 by r2;	// bit0=1, link with F
		r0 = BSET r0 by r2;
P054_L0:
		r2 = r2 - 1, dm(i2, 26) = r0;	// channel A,B,C,D,E link status

	dm(i2, 26) = r12;					// channel F link status
	jump (pc, P007_L0);

P040:		//(ID$040CVVV, CH Source
	i2 = _outputChannel + 1;
	r8 = 3;								// i4 -> _uart_rxbuf + 8;
	call _GetNumberFromUart;

	r8 = 26;
	r8 = r8 * r12(UUI);
	m4 = r8;
	dm(m4, i2) = r0;

	jump (pc, P007_L0);

P041:		//(ID$041CVVV, Crossover LCF Type
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 2;
	r8 = 3;

P042:		//(ID$042CVVV, Crossover LCF Freq
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 3;
	r8 = 3;

P043:		//(ID$043CVVV, Crossover HCF Type
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 4;
	r8 = 3;

P044:		//(ID$044CVVV, Crossover HCF Freq
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 5;
	r8 = 3;

P045:		//(ID$045CBBTTTFFFLLLQQQ, CH PEQ Type,Freq,Level,Q
	i2 = _outputChannel + 6;
	r14 = 2;							// band 0, 1, 2 possible
	call _bandCheck;
	bit tst ustat4 BIT_14;
	if TF jump _uart_error_process;

	r8 = 26;
	r8 = r8 * r12(UUI);
	r14 = LSHIFT r14 by 2;
	r8 = r8 + r14;
	m4 = r8;

	r8 = 3;								// i4 -> _uart_rxbuf + 10;
	call _GetNumberFromUart;			// Type
	dm(m4, i2) = r0;
	modify(i2, m6);
	call _GetNumberFromUart;			// freq
	dm(m4, i2) = r0;
	modify(i2, m6);
	call _GetNumberFromUart;			// Level
	dm(m4, i2) = r0;
	modify(i2, m6);
	call _GetNumberFromUart;			// Q
	dm(m4, i2) = r0;

	jump (pc, P007_L0);

P046:		//(ID$046CBBVVV, CH PEQ Freq
	i2 = _outputChannel + 7;
	jump P048 + 1;

P047:		//(ID$047CBBVVV, CH PEQ Level
	i2 = _outputChannel + 8;
	jump P048 + 1;

P048:		//(ID$048CBBVVV, CH PEQ Q
	i2 = _outputChannel + 9;

	r14 = 2;							// band 0, 1, 2 possible
	call _bandCheck;
	bit tst ustat4 BIT_14;
	if TF jump _uart_error_process;

	r8 = 26;
	r8 = r8 * r12(UUI);
	r14 = LSHIFT r14 by 2;
	r8 = r8 + r14;
	m4 = r8;

	r8 = 3;								// i4 -> _uart_rxbuf + 10;
	call _GetNumberFromUart;			// Freq, Level or Q
	dm(m4, i2) = r0;

	jump (pc, P007_L0);

P049:		//(ID$049CVVV, CH Level
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 18;
	r8 = 3;

P050:		//(ID$050CVVV, Peak Limiter Threshold
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 19;
	r8 = 3;

P051:		//(ID$051CVVVVVV, CH Delay
	i2 = _outputChannel + 20;

	r8 = 6;								// i4 -> _uart_rxbuf + 8;
	call _GetNumberFromUart;

	r8 = 26;
	r8 = r8 * r12(UUI);
	m4 = r8;

	r4 = FEXT r0 by 24:8;				// MSB first
	dm(m4, i2) = r4;
	r4 = FEXT r0 by 16:8, r8 = dm(i2, m6);	// i2++
	dm(m4, i2) = r4;
	r4 = FEXT r0 by 8:8, r8 = dm(i2, m6);	// i2++
	dm(m4, i2) = r4;
	r4 = FEXT r0 by 0:8, r8 = dm(i2, m6);	// i2++
	dm(m4, i2) = r4;

	jump (pc, P007_L0);

P052:		//(ID$052CVVV, CH Phase
	jump (pc, P040 + 2);
	i2 = _outputChannel + 24;
	r8 = 3;

P053:		//(ID$053CVVV, CH Muting
	jump (pc, P040 + 2)(DB);
	i2 = _outputChannel + 25;
	r8 = 3;
