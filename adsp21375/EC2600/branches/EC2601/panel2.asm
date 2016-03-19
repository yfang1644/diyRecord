//////////////////////////////////////////////////////////////////////////////
//NAME:     pane2.asm                                                       //
//DATE:     2010-11-22                                                      //
//PURPOSE:                                                                  //
//                                                                          //
//USAGE:    This file contains the setup routine for panel LEDs and switches//
//          interrupt service routine for handling IRQ1                     //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////

#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"
#include "flash.h"

.extern _parametersInit;

.extern _div10;
.extern _inpParam, _inPower;
.extern _Company, _DeviceInfo, _SoftwareVersion;
.extern _remoteID, _programNo, _panelStatus;
.extern _readFlash, _writeFlash, _programCheck;
.extern _tempUserData;

.extern _compOnOff, _outputChannel;
.extern _programOutputStatus;
.section/dm seg_dmda;
.var switch_jump_table[] =
		0x0b7e, MUTE_IN0,	  _MUTE_IN0,	// MAX7301 P24, FLG9=0
		0x0b7d, MUTE_IN1,	  _MUTE_IN1,	// MAX7301 P25, FLG9=0
		0x0b7b, MUTE_OUT0,	  _MUTE_OUT0,	// MAX7301 P26, FLG9=0
		0x0b77, MUTE_OUT1,	  _MUTE_OUT1,	// MAX7301 P27, FLG9=0
		0x0b6f, MUTE_OUT2,	  _MUTE_OUT2,	// MAX7301 P28, FLG9=0
		0x0b5f, MUTE_OUT3,	  _MUTE_OUT3,	// MAX7301 P29, FLG9=0
		0x0b3f, MUTE_OUT4,	  _MUTE_OUT4,	// MAX7301 P30, FLG9=0
		0x0e6f, MUTE_OUT5,    _MUTE_OUT5,	// MAX7301 P28, FLG8=0
		0x0e7e, SWITCH_DOWN,  _SWITCH_DOWN,	// MAX7301 P24, FLG8=0
		0x0e7d, SWITCH_UP,	  _SWITCH_UP,	// MAX7301 P25, FLG8=0
		0x0e7b, SWITCH_DISP,  _SWITCH_DISP,	// MAX7301 P26, FLG8=0
		0x0e77, SWITCH_ENTER, _SWITCH_ENTER;// MAX7301 P27, FLG8=0

.var _dBlevel[] =
		StandardN40dB,
		StandardN20dB,
		StandardN10dB,
		StandardN6dB,
		Standard0dB;

.global _blink88, _switchInterval, _levelIndicator;
.var _blink88 = LED_FLASH_RATE;			// blink rate 50*10ms
.var _switchInterval = SWITCH_DELAY;	// limit switch speed for UP/DOWN key
.var _levelIndicator = LEVEL_INDICATOR;
.var _Up_Down_Key = 0;					// mark Up/Down key, for continous active

.section/dm seg_dm16;
.var _manual = -2;						// -2 --uart, -1 -- manual
.var _panelInitTable[] =
		// IC2     IC1     IC0
		0x0955, 0x0955, 0x0955,		// output 3*4
		0x0a55, 0x0a55, 0x0a55,		// output 3*4
		0x0b55, 0x0b55, 0x0b55,		// output 3*4
		0x0c55, 0x0c55, 0x0c55,		// output 3*4
		0x0d55, 0x0d55, 0x0d55,		// output 3*4
		0x0eff, 0x0e55, 0x0e55,		// input 4, output 2*4,
		0x0f7f, 0x0f55, 0x0f55,		// output 1, input 3, output 2*4
		0x067f, 0x0600, 0x0600;		// mask register

// IC2:	2个8段管(P8-P15, P16-P23)，7个switches(P24-P30, P31输出中断)
//		P4:Program, P5:Status, P6:Remote/IO, P7:Lock
// IC1:	P4-10:Out2 Volume, P11-17:Out3 Volume, P18-24:Out4 Volume
//		P25-31:Out5 Volume (OutVolume:Limiter-Over-6dB-10dB-20dB-40dB-Mute)
// IC0: P4-10: In0 Volume, P11-17: In1 Volume, P18-24:Out0 Volume
//		P25-31:Out1 Volume (InVolume:Comp-Over-6dB-10dB-20dB-40dB-Mute)
// 每组IC1、IC2有效7位，最高位恒1，留待下组最低位设置

.global _panelCommandTable;
.var _panelCommandTable[] =			// 低位对齐
		0x4000, 0x4480, 0x4480,		// FUNC(4),       P4-10(OUT2),  P4-10( IN0)
		0x4800, 0x4b80, 0x4b80,		// ports(LED A), P11-17(OUT3), P11-17( IN1)
		0x5000, 0x5280, 0x5280,		// ports(LED B), P18-24(OUT4), P18-24(OUT0)
		0x0000, 0x5980, 0x5980,		// ports in,     P25-31(OUT5), P25-31(OUT1)
		0x0481, 0x0401, 0x0401,
		0xd800, 0x0000, 0x0000;

.var _digitBlackTemp[] = 0x48C0, 0x50F9;	//panelCommandTable[3,6]

.var _Led8chars[16] =					// 0-9, A,b,C,d,E,F
		0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8,
		0x80, 0x90, 0x88, 0x83, 0xc6, 0xa1, 0x86, 0x8e;

// IN、OUT共8列电平指示灯，对应 _panelCommandTable表中的位置
// IN0, IN1, OUT0, OUT1, OUT2, OUT3, OUT4, OUT5
// bit6: mute
// bit5-bit1: -40dB-- 0dB
// bit0:In-Comp or Out-Limiter
.global _ledtable;
.var _ledtable[] = 2, 5, 8, 11, 1, 4, 7, 10;

.var _disp_programNo = 1;
.var _disp_remoteID = 1;

.section/pm seg_pmco;
/*
	output commands and settings to MAX7301AAX(3 ICs)
	i4: pointer
	r4: one group of setting
*/
.global _updatePanel;
_updatePanel:
	lcntr = r4, do (pc, setMax7301) until lce;
		dm(SPIFLGB) = ustat2;
		r0 = dm(i4, m6);
		dm(TXSPIB) = r0;
		ustat1 = dm(SPISTATB);
		bit tst ustat1 SPIFE;
		if not TF jump (pc, -2);

		r0 = dm(i4, m6);
		dm(TXSPIB) = r0;
		ustat1 = dm(SPISTATB);
		bit tst ustat1 SPIFE;
		if not TF jump (pc, -2);

		r0 = dm(i4, m6);
		dm(TXSPIB) = r0;
		ustat1 = dm(SPISTATB);
		bit tst ustat1 SPIFE;
		if not TF jump (pc, -2);
		dm(SPIFLGB) = ustat3;
		nop;
setMax7301:
		nop;

	rts;
_updatePanel.end:

.global _initPanel;
_initPanel:
	ustat1 = 0;
	dm(SPICTLB) = ustat1;
	dm(SPIFLGB) = ustat1;

	ustat2 = 0xfd02;					// SPI FLAG1 low
	ustat3 = 0xff02;					// SPI FLAG1 high
	// Pclk(peripheral clock=core clock/2)
	// min. clock of MAX7301 is 38.4ns, about 26MHz
	// baud rate = Pclk/divisor
	ustat1 = 8;							// Setup the baud rate to 13MHz
	dm(SPIBAUDB) = ustat1;

	ustat1 = 0							// Set the SPIB control register
			|SPIEN						// enable the port
			|SPIMS						// DSP as SPI master
			|MSBF						// MSB first
			|CLKPL						// clock polarity
			|CPHASE						// send CS_ manually
			|WL16						// word length = 16 bits
			|TIMOD1;
	dm(SPICTLB) = ustat1;

	ustat1=dm(SYSCTL);
	bit set ustat1 IRQ1EN;				// Flag1 used as IRQ1
	dm(SYSCTL)=ustat1;
	bit SET MODE2 IRQ1E;				// IRQ pins edge sensitive
	bit CLR IRPTL IRQ1I;
	bit CLR IMASK IRQ1I;

//	bit SET FLAGS FLG8O|FLG9O;			// Enable Flag8 and Flag9 output
	bit SET ustat4 BIT_28;				// disable switch delay
	bit CLR ustat4 BIT_20|BIT_29;		// stop LED8 blinks(BIT_20)
										// start level indicator(BIT_29)
	bit CLR ustat4 BIT_22;

	bit CLR FLAGS FLG8;					// Enable panel-key input
	bit SET FLAGS FLG9;					// prepare to test UP/DONW keys

	call _updatePanel(DB);
	i4 = _panelInitTable;
	r4 = (@_panelInitTable + @_panelCommandTable)/3;

	r4 = r4 - r4, r0 = m5;				//r4=0(machine info sect), r0=0(machine ID)
	CCALL (_programCheck);
	r0 = 50;							// machine ID=1~50
	comp (r2, r0);						// memory should be 0xFF in new machine
	if LE jump (pc, not_new_machine), else r4 = r4 - r4;
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_writeFlash);

	r4 = 1;
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);

	r4 = 51;
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);

not_new_machine:
	r4 = 0;
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_readFlash);

	r4 = 51;
	r0 = PROG_VALID;
	CCALL (_programCheck);				// is default program valid?
	r2 = pass r2;
	if NE jump (pc, _default_program_invalid);

	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_readFlash);
	r8 = dm(_programNo);
	dm(_disp_programNo) = r8;
	call _digitDisplay00;

_default_program_invalid:

	r8 = dm(RXSPIB);

	r4 = 0x8000000;
	lcntr = r4, do (pc, 1) until lce;
		nop;

	call _updatePanel(DB);
	i4 = _panelInitTable + 15;
	r4 = 1;

	r8 = dm(RXSPIB);
	r4 = -2;							// defalut to UART controling
	BTST r8 by 2;						// check DISPLAY key
	if SZ r4 = r4 + 1;					// set to Manually
	dm(_manual) = r4;

	BTST r8 by 0;						// check DOWN key, UNLOCK on power
	if SZ jump (pc, poweron_lock)(DB);
	r1 = 0;								// panel status = UNLOCK
	r0 = 0x40fe;						// LOCK indicator OFF

	BTST r8 by 1;						// check UP key, LOCK on power
	if SZ jump (pc, poweron_lock)(DB);
	r1 = 4;								// panel status = LOCK
	r0 = 0x40f6;						// LOCK indicator ON

no_key:
	r8 = dm(_panelStatus);				// r1 = 4
	r1 = r1 AND r8;						// keep panelLock status
	if NE jump (pc, 3);					// LOCK, r0 = 0x40f6
	r0 = 0x40fe;
	bit CLR ustat4 BIT_28;				// enable switch delay(IRQ1 enable)
	dm(_panelStatus) = r1;
	jump _updatePanel(DB);
	dm(_panelCommandTable + 0) = r0;
	r4 = 1;

poweron_lock:
	dm(_panelStatus) = r1;
	r1 = pass r1;
	if NE jump (pc, 2);
	bit CLR ustat4 BIT_28;
	call (pc, _updatePanel)(DB);
	dm(_panelCommandTable + 0) = r0;
	r4 = 1;

	r4 = 0;
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_writeFlash);
	rts;
_initPanel.end:

/*
	put display code into digit(88) to display or blink
	input: r8
	(r0, r8) = r8/10; r0=quotient, r8 = reminder
	_digitDisplay00, radix 10
	_digitDisplayFF, radix 16
	changed register: r0, r8, r2
*/
.global _digitDisplay00;
_digitDisplay00:
	CCALL (_div10);
_digitDisplayFF:
	i4 = _Led8chars;
	m4 = r0;
	r0 = dm(m4, i4);					// digit code of quotient
	r2 = 0x4800;
	m4 = r8;
	r2 = r2 + r0, r8 = dm(m4, i4);		// digit code of reminder
	dm(_panelCommandTable + 3) = r2;
	dm(_digitBlackTemp + 0) = r2;
	r2 = 0x5000;
	rts(DB), r2 = r2 + r8;
	dm(_panelCommandTable + 6) = r2;
	dm(_digitBlackTemp + 1) = r2;
_digitDisplay00.end:

/* Update channel sources and frequency ranges in Panel status mode */
.global _statusUpdate;
_statusUpdate:
	i8 = _ledtable + 2;
	i4 = _panelCommandTable;
	i2 = _programOutputStatus;
	r3 = 0xff80;
	lcntr = OUTS, do (pc, 5) until lce;
		m4 = pm(i8, m14);
		r0 = dm(m4, i4);
		r0 = r0 AND r3, r4 = dm(i2, m6);
		r0 = r0 OR r4;
		dm(m4, i4) = r0;

	rts;
_statusUpdate.end:

.global _digitBlink;
_digitBlink:
	r0 = 0x48ff;
	r1 = 0x50ff;
	bit TGL ustat4 BIT_21;
	bit TST ustat4 BIT_21;				// blank or lid
	if TF jump(pc, 3);
	r0 = dm(_digitBlackTemp + 0);
	r1 = dm(_digitBlackTemp + 1);
	dm(_panelCommandTable + 3) = r0;
	dm(_panelCommandTable + 6) = r1;

	rts(DB);
	r0 = LED_FLASH_RATE;
	dm(_blink88) = r0;
_digitBlink.end:

.global _levelBlink;
_levelBlink:
	i4 = _panelCommandTable;
	bit TST ustat4 BIT_29;				//BIT_29 used to display output status
	if TF jump no_blink;
	i5 = _inPower;
	i12 = _inpParam + 5;				// Compressor active
	i8 = _ledtable;
	r10 = 0x00bf;						// 1-Mute-x-x-x-x-x-Limit
	i10 = _dBlevel;
	m10 = -5;
	lcntr = INS + OUTS, do level1 until lce;
		m4 = pm(i8, m14);
		r0 = dm(m4, i4);
		r0 = r0 OR r10, r8 = pm(i12, 6);	// 1 means compressor
		r0 = r0 XOR r8, r4 = dm(i5, m6), r8 = pm(i10, m14);
		// r4=power, r8=level
		comp (r4, r8), r8 = pm(i10, m14);
		if GT r0 = BCLR r0 by 5;		// -40dB
		comp (r4, r8), r8 = pm(i10, m14);
		if GT r0 = BCLR r0 by 4;		// -20dB
		comp (r4, r8), r8 = pm(i10, m14);
		if GT r0 = BCLR r0 by 3;		// -10dB
		comp (r4, r8), r8 = pm(i10, m14);
		if GT r0 = BCLR r0 by 2;		// -6dB
		comp (r4, r8),  modify(i10, m10);
		if GT r0 = BCLR r0 by 1;		// over 0dB
level1:
		dm(m4, i4) = r0;

no_blink:
//	r0 = LEVEL_INDICATOR;
	jump (pc, _updatePanel)(DB);
//	dm(_levelIndicator) = r0;
	r4 = 5;
	nop;
_levelBlink.end:

/*
	Import: No parameter
	Changed registers: all registers
	Export: No parameter
*/
.global _keyProcessing;
_keyProcessing:
	dm(_Up_Down_Key) = m5;
	r4 = 0x00080000;
	lcntr = r4, do (pc, 1) until lce;
		nop;
	
	call (pc, _updatePanel)(DB);
	i4 = _panelCommandTable + 15;
	r4 = 1;
	r3 = dm(RXSPIB);
	
	call (pc, _updatePanel)(DB);
	i4 = _panelCommandTable + 15;
	r4 = 1;
	r3 = dm(RXSPIB);
	
	r4 = FLAGS;

	r8 = FEXT r3 by 0:7;
	r4 = FEXT r4 by 16:4;
	r8 = r8 OR FDEP r4 by 8:4;
	i4 = switch_jump_table;
	m2 = dm(_manual);
	lcntr = @switch_jump_table/3, do (pc, 3) until lce;
		r10 = dm(i4, 3);
		comp (r8, r10);
		if EQ jump switch_hit(LA);

	jump EndKeyPortJudge;				// switch not matched, do nothing

switch_hit:
	r4 = r4 - r4, i12 = dm(m2, i4);
	jump (m13, i12);
_keyProcessing.end:


MUTE_OUT5:								// output channel 5(r4=7)
	r4 = r4 + 1;
MUTE_OUT4:								// output channel 4(r4=6)
	r4 = r4 + 1;
MUTE_OUT3:								// output channel 3(r4=5)
	r4 = r4 + 1;
MUTE_OUT2:								// output channel 2(r4=4)
	r4 = r4 + 1;
MUTE_OUT1:								// output channel 1(r4=3)
	r4 = r4 + 1;
MUTE_OUT0:								// output channel 0(r4=2)
	r4 = r4 + 1;
MUTE_IN1:								// input channel 1 settings(r4=1)
	r4 = r4 + 1;
MUTE_IN0:								// input channel 0 settings(r4=0)
	i4 = _panelCommandTable;
	i2 = _ledtable;
	m2 = r4;
	m4 = dm(m2, i2);
	r8 = 6;								// struct _inpParam 6xINS
	r8 = r8 * r4(UUI), r12 = dm(m4, i4);
	r12 = BTGL r12 by 6;				// Mute indicator bit
	r0 = FEXT r12 by 6:1;
	dm(m4, i4) = r12;					// MUTE light-on/off toggle

	i4 = _inpParam + 1;					// i4 -> _inpParam.mute
	m4 = r8;
	dm(m4, i4) = r0;
	i4 = _compOnOff;
	r2 = INS;
	r4 = r4 - r2, r3 = m6;
	if LT jump (pc, _muteInParamSet), r4 = r4 + r2;
	i4 = _outputChannel + 25;			// ChMute
	r8 = 26;
	r8 = r8 * r4(UUI), m2 = r4;
	m4 = r8;
	dm(m4, i4) = r0;					// 0=OUT-mute
	i4 = _programOutputStatus;
	r4 = dm(m2, i4);
	r4 = BCLR r4 by 6;
	r4 = r4 OR LSHIFT r0 by 6;
	dm(m2, i4) = r4;					// output status MUTE bit
	jump EndKeyPortJudge;
_muteInParamSet:
	r0 = r3 - r0, m4 = r4;				// 1=IN-mute
	dm(m4, i4) = r0;
	jump EndKeyPortJudge;

SWITCH_DISP:							// DISPLAY KEY
	bit CLR ustat4 BIT_20|BIT_29;		// stop LED8 blink anyway(BIT_20)
										// start level indicator(BIT_29)
	r8 = dm(_programNo);
	dm(_disp_programNo) = r8;
	call _digitDisplay00;
	r0 = dm(_remoteID);
	dm(_disp_remoteID) = r0;
	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;				// bit1-0: Prog., Status, or RemoteID
	r0 = r0 + 1;						// panel not locked
	r2 = 3;
	comp (r0, r2);
	if GE r0 = r0 - r0;					// skip '3'
	r8 = 0x40ff;						// set LSB0-2 of IC2(P4-P6)
	r8 = BCLR r8 by r0, r4 = m5;		// Prog., Status, or RemoteID, r4=0
	jump (pc, _UP_DOWN_KEY_PROCESS + 5)(DB);
	dm(_panelCommandTable) = r8;
	dm(_panelStatus) = r0;

SWITCH_ENTER:							// ENTER/RECALL KEY
	bit TGL ustat4 BIT_20;

	r0 = dm(_digitBlackTemp + 0);
	r1 = dm(_digitBlackTemp + 1);
	dm(_panelCommandTable + 3) = r0;
	dm(_panelCommandTable + 6) = r1;
	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, loadParameters), else r0 = r0 - 1;
	if NE jump (pc, saveRemoteID);

EndKeyPortJudge:
	call (pc, _updatePanel)(DB);
	i4 = _panelCommandTable + 0;
	r4 = 4;								//re-enable transition detection
	r3 = dm(_Up_Down_Key);
	r3 = pass r3;
	if NE jump key_released;
wait_key_release:
	call (pc, _updatePanel)(DB);
	i4 = _panelCommandTable + 15;
	r4 = 1;
	r3 = dm(RXSPIB);
	r4 = 0x7f;
	r3 = FEXT r3 by 0:7;
	comp (r3, r4);
	if NE jump wait_key_release;
key_released:
	bit CLR ustat4 BIT_30;
	rts;								// return from key proccessing

loadParameters:
	bit TST ustat4 BIT_20;				// neccessary!
	if TF jump dispStatus;				// blinking..., display status

	r8 = dm(_programNo);
	r4 = dm(_disp_programNo);
	comp (r8, r4);
	if EQ jump _same_program;

	r4 = dm(_disp_programNo);
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_readFlash);
	r4 = 51;
	i2 = _programNo;
	CCALL (_writeFlash);

_same_program:
	bit CLR ustat4 BIT_29;				// start level indicator
	call _parametersInit;
	r8 = dm(_programNo);
	call _digitDisplay00;
	jump EndKeyPortJudge;

saveRemoteID:
	bit TST ustat4 BIT_20;				// neccessary!
	if TF jump EndKeyPortJudge;			// blinking..., nothing to do

	r8 = dm(_disp_remoteID);
	i2 = _remoteID;
	r4 = r4 - r4, dm(i2, m5) = r8;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_writeFlash);
	jump EndKeyPortJudge;

SWITCH_UP:								// UP KEY
	jump (pc, _UP_DOWN_KEY_PROCESS), r4 = r4 + 1;

SWITCH_DOWN:							// DOWN KEY
	jump (pc, _UP_DOWN_KEY_PROCESS), r4 = r4 - 1;

/*
	Import: R4(-1:DOWN KEY, +1:UP KEY), _panelStatus ...
	Used regitster:
	Export: No
*/
_UP_DOWN_KEY_PROCESS:
	dm(_Up_Down_Key) = m6;
	bit TST ustat4 BIT_20;
	if not TF jump (pc, EndKeyPortJudge)(DB);	// not blinking, return
	r0 = SWITCH_DELAY;
	dm(_switchInterval) = r0;

	r0 = SWITCH_DELAY + LED_FLASH_RATE;
	dm(_blink88) = r0;
	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, changeProgramNo), else r0 = r0 - 1;	// _panelState=0
	if NE jump (pc, changeRemoteID);	// _panelState=2
//	if SZ jump (pc, changeProgramNo), else r0 = r0 - 1;	// _panelState=0
//	if EQ jump (pc, dispStatus), else r0 = r0 - 1;// _panelState=1
//	if EQ jump (pc, changeRemoteID);	// _panelState=2

dispStatus:								// _panelState=1
	bit SET ustat4 BIT_29;				// stop level indicator
	i8 = _ledtable + 2;
	i4 = _panelCommandTable;
	i2 = _programOutputStatus;
	r3 = 0xff80;
	lcntr = OUTS, do (pc, 5) until lce;
		m4 = pm(i8, m14);
		r0 = dm(m4, i4);
		r0 = r0 AND r3, r4 = dm(i2, m6);
		r0 = r0 OR r4;
		dm(m4, i4) = r0;

	r0 = dm(_digitBlackTemp + 0);
	r1 = dm(_digitBlackTemp + 1);
	dm(_panelCommandTable + 3) = r0;
	dm(_panelCommandTable + 6) = r1;
	jump EndKeyPortJudge;

changeProgramNo:
	r3 = pass r4, r0 = m6;		// r0 = PROG_VALID
	if EQ jump check_nothing;

	r4 = dm(_disp_programNo);
	r8 = 50;
	lcntr = 50, do (pc, check_recall) until lce;
		r4 = r4 + r3;
		if LE r4 = r4 - r3;		// New ProgramNo <=0
		r4 = MIN(r4, r8);

		CCALL (_programCheck);		// check program valid

		r5 = dm(PROG_RECALL, i4);
		r2 = r2 OR r5;
		if EQ jump (pc, recall_valid)(LA), r8 = pass r4;
check_recall:
		nop;
check_nothing:
	r8 = dm(_disp_programNo);
	call _digitDisplay00;
	jump EndKeyPortJudge;

recall_valid:
//	bit CLR ustat4 BIT_29;				// start level indicator
	i2 = i4;
	dm(_disp_programNo) = r8;
	call _digitDisplay00;
	i8 = _ledtable + 2;
	i4 = _panelCommandTable;
	r3 = 0xff80;
	modify(i2, _programOutputStatus - _programNo);
	lcntr = OUTS, do (pc, 5) until lce;
		m4 = pm(i8, m14);
		r0 = dm(m4, i4);
		r0 = r0 AND r3, r4 = dm(i2, m6);
		r0 = r0 OR r4;
		dm(m4, i4) = r0;

	jump (pc, EndKeyPortJudge);

changeRemoteID:
	r8 = dm(_disp_remoteID);
	r8 = r8 + r4, r4 = m6;
	r8 = MAX(r8, r4);					// remoteID >= 1
	r4 = 50;
	r8 = MIN(r8, r4);					// remoteID <= 50
	dm(_disp_remoteID) = r8;
	call _digitDisplay00;
	
	jump (pc, EndKeyPortJudge);

// =========================== manual version ========================

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

.section/dm seg_dmda;

.var _input_switch_table[] =					// 根据 MUTE_IN0, MUTE_IN1位置
		dispInputDelay,		changeInputDelay,	// 调出显示数字, Up/Dn改变值
		dispInputGain,		changeInputGain,
		dispInputPEQNo,		changeInputPEQNo,
		dispInputPEQType,	changeInputPEQType,
		dispInputPEQFreq,	changeInputPEQFreq,
		dispInputPEQLevel,	changeInputPEQLevel,
		dispInputPEQQ,		changeInputPEQQ,
		dispInputMuteState,	toggleInputMuteState,
		dispInputThreshold,	changeInputThreshold,
		dispInputCompRatio,	changeInputCompRatio;

.var _output_switch_table[] =					// 根据 MUTE_OUT0~OUT7位置
		dispOutputDelay,	changeOutputDelay,	// 调出显示数字, Up/Dn改变值
		dispOutputGain,		changeOutputGain,
		dispOutputPEQNo,	changeOutputPEQNo,
		dispOutputPEQType,	changeOutputPEQType,
		dispOutputPEQFreq,	changeOutputPEQFreq,
		dispOutputPEQLevel,	changeOutputPEQLevel,
		dispOutputPEQQ,		changeOutputPEQQ,
		dispOutputMuteState,toggleOutputMuteState,
		dispOutputThreshold,changeOutputThreshold,
		dispOutputLink,		changeOutputLink;

.var _lastSwitch = 0;

.var _switchPosition[INS+OUTS+2] =
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0;
// INS, OUTS , enter, display, 10 keys
// In0, In1: Delay, Gain, InPEQ_No., PEQ_type, Freq, Level, Q, Mute
// Out0... Out5:Delay, Gain, Link, OutFl_No., Flt_type, Freq, Level, Q,Mute
// enter/recall:
// display:
// UP:
// DOWN:

// 用于 PEQ 参数改变的对应通道指针
.var _adjustInputPEQPointer[INS] = 0, 0;
.var _adjustOutputPEQPointer[OUTS] = 0, 0, 0, 0, 0, 0;

.section/pm seg_pmco1;

_MUTE_IN1:								// input channel 1 settings(r4=1)
	r4 = r4 + 1;
_MUTE_IN0:								// input channel 0 settings(r4=0)

	dm(_Up_Down_Key) = m6;
	r0 = SWITCH_DELAY * 2;
	dm(_switchInterval) = r0;
	dm(_lastSwitch) = r4;
	i8 = _ledtable;
	i0 = _panelCommandTable;
	r12 = 0xff;
	lcntr = INS+OUTS, do (pc, 4) until lce;
		m2 = pm(i8, m14);
		r0 = dm(m2, i0);
		r0 = r0 OR r12;
		dm(m2, i0) = r0;				// light-off In/-dB

	i2 = _ledtable;
	m4 = r4;
	m2 = dm(m4, i2);
	r12 = dm(m2, i0);
	r12 = BCLR r12 by 6;
	dm(m2, i0) = r12;					/// light-on Mute, MUTE indication.

	i4 = _switchPosition;
	r0 = dm(m4, i4);
	r0 = r0 + 1;
	r1 = @_input_switch_table / 2;
	comp(r0, r1);
	if GE r0 = r0 - r0;
	r0 = r0 + r0, dm(m4, i4) = r0;
	i2 = _input_switch_table;
	m2 = r0;
	i12 = dm(m2, i2);
	jump (m13, i12);

dispInputDelay:
	r8 = _masterDelay;
	r0 = LSHIFT r4 by 2;
	r0 = r0 + r8;
	i2 = r0;

	r8 = r8 - r8, r0 = dm(i2, m6);
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m6);
	r8 = r8 OR LSHIFT r0 by 8, r0 = dm(i2, m6);
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m6);
	r8 = r8 OR LSHIFT r0 by 8; 

	f12 = 1. / 2621.44;
	f8 = FLOAT r8;
	f8 = f8 * f12;						// percent of Max. delay time
	r8 = FIX f8;
	call _digitDisplay00;
	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 2;
	dm(_panelCommandTable + 2) = r0;	// light In0/-6dB

	jump EndKeyPortJudge;

dispInputGain:
	i4 = _PEQLevel;
	r8 = dm(m4, i4);					// gain = 0.5v - 181 , v=0-205
	r0 = 181;
	r8 = r8 - r0;
	r8 = ABS r8;
	r8 = ASHIFT r8 by -1;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 2) = r0;	// light In0/-10dB

	jump EndKeyPortJudge;

dispInputPEQNo:
	i4 = _adjustInputPEQPointer;
	r8 = dm(m4, i4);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 2) = r0;	// light In0/-20dB

	jump EndKeyPortJudge;

dispInputPEQType:
	i4 = _adjustInputPEQPointer;
	r8 = dm(m4, i4);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter;
	m2 = r8;
	r8 = dm(m2, i2);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 2) = r0;	// light In0/-40dB

	jump EndKeyPortJudge;

dispInputPEQFreq:
	i4 = _adjustInputPEQPointer;
	r8 = dm(m4, i4);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter + 1;
	m2 = r8;
	r0 = dm(m2, i2);
	r8 = FEXT r0 by 0:4;
	r0 = FEXT r0 by 4:4;
	call _digitDisplayFF;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 2;
	dm(_panelCommandTable + 5) = r0;	// light In1/-6dB

	jump EndKeyPortJudge;

dispInputPEQLevel:
	i4 = _adjustInputPEQPointer;
	r8 = dm(m4, i4);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter + 2;
	m2 = r8;
	r0 = dm(m2, i2);
	r8 = 24;
	r8 = r0 - r8;
	r8 = ABS r8;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 5) = r0;	// light In1/-10dB

	jump EndKeyPortJudge;

dispInputPEQQ:
	i4 = _adjustInputPEQPointer;
	r8 = dm(m4, i4);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter + 3;
	m2 = r8;
	r8 = dm(m2, i2);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 5) = r0;	// light In1/-20dB
	jump EndKeyPortJudge;

dispInputThreshold:
	i4 = _compThreshold;
	r8 = dm(m4, i4);					// dBFS = -0.5v, v=0-96
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 1;
	dm(_panelCommandTable + 2) = r0;	// light In0/Over
	jump EndKeyPortJudge;

dispInputCompRatio:
	i4 = _compRatio;
	r8 = dm(m4, i4);					// g = 1-v/100, v=0-100
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 0;
	dm(_panelCommandTable + 2) = r0;	// light In0/Limiter
	jump EndKeyPortJudge;

dispInputMuteState:
	i4 = _compOnOff;
	r0 = dm(m4, i4);

	i8 = _ledtable;
	m10 = r4;
	m2 = pm(m10, i8);
	i0 = _panelCommandTable;
	r4 = dm(m2, i0);

	r4 = BSET r4 by 6;
	r0 = pass r0;
	if NE r4 = BCLR r4 by 6;
	dm(m2, i0) = r4;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 5) = r0;	// light In1/-40dB
	r0 = 0x48bf;						// display '--'
	r1 = 0x50bf;
	jump EndKeyPortJudge(DB);
	dm(_digitBlackTemp + 0) = r0;
	dm(_digitBlackTemp + 1) = r1;


_MUTE_OUT5:								// output channel 5(r4=7)
	r4 = r4 + 1;
_MUTE_OUT4:								// output channel 4(r4=6)
	r4 = r4 + 1;
_MUTE_OUT3:								// output channel 3(r4=5)
	r4 = r4 + 1;
_MUTE_OUT2:								// output channel 2(r4=4)
	r4 = r4 + 1;
_MUTE_OUT1:								// output channel 1(r4=3)
	r4 = r4 + 1;
_MUTE_OUT0:								// output channel 0(r4=2)
	r4 = r4 + 1;
	r4 = r4 + 1;

	dm(_lastSwitch) = r4;

	dm(_Up_Down_Key) = m6;
	r0 = SWITCH_DELAY * 2;
	dm(_switchInterval) = r0;

	i8 = _ledtable;
	i0 = _panelCommandTable;
	r12 = 0xff;
	lcntr = INS+OUTS, do (pc, 4) until lce;
		m2 = pm(i8, m14);
		r0 = dm(m2, i0);
		r0 = r0 OR r12;
		dm(m2, i0) = r0;				// light-off In/-dB

	i2 = _ledtable + INS;
	r2 = INS;
	r4 = r4 - r2;
	m4 = r4;
	m2 = dm(m4, i2);
	r12 = dm(m2, i0);
	r12 = BCLR r12 by 6;
	dm(m2, i0) = r12;					// light-on MUTE

	i4 = _switchPosition + INS;
	r0 = dm(m4, i4);
	r0 = r0 + 1;
	r1 = @_output_switch_table / 2;
	comp(r0, r1);
	if GE r0 = r0 - r0;
	r0 = r0 + r0, dm(m4, i4) = r0;
	i2 = _output_switch_table;
	m2 = r0;
	i12 = dm(m2, i2);
	jump (m13, i12);

dispOutputDelay:
	r2 = _outputChannel + 20;			// output delay
	r8 = 26;
	r8 = r8 * r4(UUI);
	r8 = r8 + r2;
	i2 = r8;

	r8 = r8 - r8, r0 = dm(i2, m6);
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m6);
	r8 = r8 OR LSHIFT r0 by 8, r0 = dm(i2, m6);
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m6);
	r8 = r8 OR LSHIFT r0 by 8; 

	f12 = 1. / 2621.44;
	f8 = FLOAT r8;
	f8 = f8 * f12;						// percent of Max. delay time
	r8 = FIX f8;
	call _digitDisplay00;
	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 2;
	dm(_panelCommandTable + 2) = r0;	// light In0/-6dB

	jump EndKeyPortJudge;

dispOutputGain:
	i2 = _outputChannel + 18;			// CHLevel
	r8 = 26;
	r8 = r8 * r4(UUI);
	m2 = r8;

	r8 = dm(m2, i2);					// gain in 0.5dB
	r0 = 181;
	r8 = r8 - r0;
	r8 = ABS r8;
	r8 = ASHIFT r8 by -1;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 2) = r0;	// light In0/-10dB

	jump EndKeyPortJudge;

dispOutputPEQNo:
	i4 = _adjustOutputPEQPointer;
	r8 = dm(m4, i4);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 2) = r0;	// light In0/-20dB

	jump EndKeyPortJudge;

dispOutputPEQType:
	i4 = _adjustOutputPEQPointer;
	m4 = r4;
	r8 = 26;
	r8 = r8 * r4(UUI), r2 = dm(m4, i4);	// r2=2,3,4 for PEQ

	r2 = r2 - 1;						// r2=0,1 for HPF, LPF
	r2 = r2 + r2;						// 2 bytes for HPF and LPF
	i2 = _outputChannel + 2;			// output PEQ_type - 4
	if GT jump (pc, 2), r2 = r2 + r2;	// 4 bytes for each PEQ
	i2 = _outputChannel + 4;			// output HPF_type + 2

	r8 = r8 + r2;
	m2 = r8;
	r8 = dm(m2, i2);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 2) = r0;	// light In0/-40dB
	jump EndKeyPortJudge;

dispOutputPEQFreq:
	i4 = _adjustOutputPEQPointer;
	m4 = r4;
	r8 = 26;
	r8 = r8 * r4(UUI), r2 = dm(m4, i4);	// r2=2,3,4 for PEQ

	r2 = r2 - 1;						// r2=0,1 for HPF, LPF
	r2 = r2 + r2;						// 2 bytes for HPF and LPF
	i2 = _outputChannel + 3;			// output PEQ_freq - 4
	if GT jump (pc, 2), r2 = r2 + r2;	// 4 bytes for each PEQ
	i2 = _outputChannel + 5;			// output HPF_freq + 2

	r8 = r8 + r2;
	m2 = r8;
	r0 = dm(m2, i2);
	r8 = FEXT r0 by 0:4;
	r0 = FEXT r0 by 4:4;
	call _digitDisplayFF;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 2;
	dm(_panelCommandTable + 5) = r0;	// light In1/-6dB
	jump EndKeyPortJudge;

dispOutputPEQLevel:
	i4 = _adjustOutputPEQPointer;
	m4 = r4;
	r8 = 26;
	r8 = r8 * r4(UUI), r2 = dm(m4, i4);	// r2=2,3,4 for PEQ

	r2 = r2 - 1;						// r2=0,1 for HPF, LPF(undefined)
	r2 = LSHIFT r2 by 2;				// 4 bytes for each PEQ
	if GT jump (pc, dispPEQL1), r8 = r8 + r2;
	r0 = 0x48bf;						// invalid parameters
	r1 = 0x50bf;						// display '--'
	dm(_digitBlackTemp + 0) = r0;
	dm(_digitBlackTemp + 1) = r1;
	jump dispPEQL2;
dispPEQL1:
	i2 = _outputChannel + 4;			// output PEQ_level - 4
	m2 = r8;
	r0 = dm(m2, i2);
	r8 = 24;
	r8 = r0 - r8;
	r8 = ABS r8;
	call _digitDisplay00;

dispPEQL2:
	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 5) = r0;    // light In1/-10dB
	jump EndKeyPortJudge;

dispOutputPEQQ:
	i4 = _adjustOutputPEQPointer;
	m4 = r4;
	r8 = 26;
	r8 = r8 * r4(UUI), r2 = dm(m4, i4);	// r2=2,3,4 for PEQ

	r2 = r2 - 1;						// r2=0,1 for HPF, LPF(undefined)
	r2 = LSHIFT r2 by 2;				// 4 bytes for each PEQ
	if GT jump (pc, dispPEQQ1), r8 = r8 + r2;
	r0 = 0x48bf;						// invalid parameters
	r1 = 0x50bf;						// display '--'
	dm(_digitBlackTemp + 0) = r0;
	dm(_digitBlackTemp + 1) = r1;
	jump dispPEQQ2;
dispPEQQ1:
	i2 = _outputChannel + 5;			// output PEQ_Q - 4
	m2 = r8;
	r8 = dm(m2, i2);
	call _digitDisplay00;

dispPEQQ2:
	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 5) = r0;	// light In1/-20dB
	jump EndKeyPortJudge;

dispOutputMuteState:
	i2 = _outputChannel + 25;			// CHMuting
	r8 = 26;
	r8 = r8 * r4(UUI), m4 = r4;
	m2 = r8;
	r0 = dm(m2, i2);

	i4 = _ledtable + INS;
	m2 = dm(m4, i4);
	i0 = _panelCommandTable;
	r4 = dm(m2, i0);

	r4 = BSET r4 by 6;
	r0 = pass r0;
	if EQ r4 = BCLR r4 by 6;
	dm(m2, i0) = r4;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 5) = r0;    // light In1/-40dB
	r0 = 0x48bf;						// display '--'
	r1 = 0x50bf;
	jump EndKeyPortJudge(DB);
	dm(_digitBlackTemp + 0) = r0;
	dm(_digitBlackTemp + 1) = r1;

dispOutputThreshold:
	i2 = _outputChannel + 19;			// PeakLimiterThreshold
	r8 = 26;
	r8 = r8 * r4(UUI);
	m2 = r8;
	r8 = dm(m2, i2);

	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 1;
	dm(_panelCommandTable + 2) = r0;	// light In0/Over
	jump EndKeyPortJudge;

dispOutputLink:
	i2 = _outputChannel + 1;			// CHSource
	r8 = 26;
	r8 = r8 * r4(UUI), m4 = r4;

	m2 = r8;
	r0 = dm(m2, i2);

	r3 = 3;
	r0 = pass r0;
	if EQ r0 = r3;

	i4 = _ledtable + INS;
	m2 = dm(m4, i4);
	i0 = _panelCommandTable;
	r4 = dm(m2, i0);

	r4 = r4 OR r3;
	r4 = r4 XOR r0;
	dm(m2, i0) = r4;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 0;
	dm(_panelCommandTable + 2) = r0;	// light In0/Comp
	r0 = 0x48bf;						// display '--'
	r1 = 0x50bf;
	jump EndKeyPortJudge(DB);
	dm(_digitBlackTemp + 0) = r0;
	dm(_digitBlackTemp + 1) = r1;

_SWITCH_DISP:							// DISPLAY KEY
	bit CLR ustat4 BIT_20|BIT_29;		// stop LED8 blink anyway
										// start level indicator
	dm(_Up_Down_Key) = m6;
	r0 = SWITCH_DELAY * 2;
	dm(_switchInterval) = r0;

	r8 = dm(_programNo);
	dm(_disp_programNo) = r8;
	call _digitDisplay00;
	r0 = dm(_remoteID);
	dm(_disp_remoteID) = r0;
	r0 = dm(_panelStatus);
	r0 = r0 + 1;						// panel not locked
	r0 = FEXT r0 by 0:2;				// bit1-0: Prog., Status, or RemoteID
	r8 = 0x40ff;						// set LSB0-2 of IC2(P4-P6)
	r8 = BCLR r8 by r0, r4 = m5;		// Prog., Status, or RemoteID, r4=0
	jump (pc, __UP_DOWN_KEY_PROCESS + 5)(DB);
	dm(_panelCommandTable) = r8;
	dm(_panelStatus) = r0;

_SWITCH_ENTER:							// ENTER/RECALL KEY
	bit TGL ustat4 BIT_20;

	dm(_Up_Down_Key) = m6;
	r0 = SWITCH_DELAY * 2;
	dm(_switchInterval) = r0;

	r0 = dm(_digitBlackTemp + 0);
	r1 = dm(_digitBlackTemp + 1);
	dm(_panelCommandTable + 3) = r0;
	dm(_panelCommandTable + 6) = r1;

	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, loadParameters);
	r0 = r0 - 1;
	if EQ jump (pc, EndKeyPortJudge);
	r0 = r0 - 1;
	if EQ jump (pc, saveRemoteID);

saveParameters:
	bit TST ustat4 BIT_20;	//
	if TF jump (pc, EndKeyPortJudge);

	r4 = dm(_disp_programNo);
	i2 = _programNo;
	dm(i2, m5) = r4;
	r8 = _tempUserData - _programNo;
	CCALL (_writeFlash);
	
	r4 = 51;
	i2 = _programNo;
	CCALL (_writeFlash);

	jump EndKeyPortJudge;

_SWITCH_UP:								// UP KEY
	jump (pc, __UP_DOWN_KEY_PROCESS), r4 = r4 + 1;

_SWITCH_DOWN:
	jump (pc, __UP_DOWN_KEY_PROCESS), r4 = r4 - 1;

/*
	Import: R4(-1:DOWN KEY, +1:UP KEY), _panelStatus ...
	Used regitster: 
	Export: No
*/
__UP_DOWN_KEY_PROCESS:
	dm(_Up_Down_Key) = m6;
	bit TST ustat4 BIT_20;
	if not TF jump (pc, EndKeyPortJudge)(DB);	// not blinking, return
	r0 = SWITCH_DELAY;
	dm(_switchInterval) = r0;

	r0 = SWITCH_DELAY + LED_FLASH_RATE;
	dm(_blink88) = r0;
	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, changeProgramNo);		// _panelState=0
	r0 = r0 - 1;
	if EQ jump (pc, _changeParameters), else r0 = r0 - 1;	// _panelState=1
	if EQ jump (pc, changeRemoteID);	// _panelState=2

_changeProgramNo:						// _panelState=3
	r8 = dm(_disp_programNo);

	r8 = r8 + r4, r4 = m6;
	r8 = MAX(r8, r4);					//New ProgramNo >=1
	r4 = 50;							//New ProgramNo <= 50
	r8 = MIN(r8, r4);
	dm(_disp_programNo) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

_changeParameters:
	bit SET ustat4 BIT_29;
	bit TST ustat4 BIT_20;				// digits are blinking
	if not TF jump EndKeyPortJudge;
	i4 = _switchPosition;
	r0 = dm(_lastSwitch);
	m4 = r0;
	r1 = INS;
	r0 = r0 - r1;
	if GE jump processOutput;

	r0 = r0 + r1, r2 = dm(m4, i4);
	r2 = r2 + r2;
	m2 = r2;
	i2 = _input_switch_table + 1;
	i12 = dm(m2, i2);
	jump (m13, i12);

changeInputDelay:
	r8 = _masterDelay;
	r0 = LSHIFT r0 by 2, puts = r0;
	r0 = r0 + r8;
	i2 = r0;

	r8 = r8 - r8, r0 = dm(i2, m6);		// high byte first, low byte last
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m6);
	r8 = r8 OR LSHIFT r0 by 8, r0 = dm(i2, m6);
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m5);	// to be restored backwards
	r8 = r8 OR LSHIFT r0 by 8; 

	f12 = 1. / 2621.44;
	f7 = FLOAT r8;
	f7 = f7 * f12;						// percent of Max. delay time
	r8 = FIX f7;
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 99;
	r8 = MIN(r8, r4);
	f7 = FLOAT r8;
	f12 = 2621.44;
	f7 = f7 * f12;
	r8 = FIX f7;

	r4 = FEXT r8 by  0:8;
	r4 = FEXT r8 by  8:8, dm(i2, m7) = r4;
	r4 = FEXT r8 by 16:8, dm(i2, m7) = r4;
	r4 = FEXT r8 by 24:8, dm(i2, m7) = r4;
	dm(i2, m5) = r4;

	call _parametersInit;
	jump dispInputDelay(DB);
	r4 = gets(1);
	alter(1);

changeInputGain:
	i2 = _PEQLevel;

	m2 = r0;
	r8 = dm(m2, i2);
	r8 = r8 + r4, puts = r0;
	r0 = 181+24;
	r8 = MIN(r8, r0);
	r0 = 181-176;
	r8 = MAX(r8, r0);
	dm(m2, i2) = r8;
	call _parametersInit;
	jump dispInputGain(DB);
	m4 = gets(1);
	alter(1);

changeInputPEQNo:
	i2 = _adjustInputPEQPointer;
	m2 = r0;							// last switch as PEQ No.
	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = IN_PEQS - 1;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

changeInputPEQType:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3, puts = r0;		// 2channels x 4 bytes
	r0 = LSHIFT r0 by 2;				// 4 bytes
	r8 = r8 + r0;
	i2 = _PEQParameter;
	m2 = r8;
	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 5;								// 5 types of PEQ
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispInputPEQType(DB);
	m4 = gets(1);
	alter(1);

changeInputPEQFreq:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3, puts = r0;		// 2channels x 4 bytes
	r0 = LSHIFT r0 by 2;				// 4 bytes
	r8 = r8 + r0;
	i2 = _PEQParameter + 1;
	m2 = r8;
	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 122;							// freq=(0~122)
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispInputPEQFreq(DB);
	m4 = gets(1);
	alter(1);

changeInputPEQLevel:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3, puts = r0;		// 2channels x 4 bytes
	r0 = LSHIFT r0 by 2;				// 4 bytes
	r8 = r8 + r0;
	i2 = _PEQParameter + 2;
	m2 = r8;
	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 48;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispInputPEQLevel(DB);
	m4 = gets(1);
	alter(1);

changeInputPEQQ:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3, puts = r0;		// 2channels x 4 bytes
	r0 = LSHIFT r0 by 2;				// 4 bytes
	r8 = r8 + r0;
	i2 = _PEQParameter + 3;
	m2 = r8;
	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 72;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispInputPEQQ(DB);
	m4 = gets(1);
	alter(1);

changeInputThreshold:
	i2 = _compThreshold;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = r8 + r4, puts = r0;
	if LT r8 = r8 - r8;
	r0 = 96;
	r8 = MIN(r0, r8);
	dm(m2, i2) = r8;
	call _parametersInit;
	jump dispInputThreshold(DB);
	m4 = gets(1);
	alter(1);

changeInputCompRatio:
	i2 = _compRatio;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = r8 + r4, puts = r0;
	if LT r8 = r8 - r8;
	r0 = 99;
	r8 = MIN(r0, r8);
	dm(m2, i2) = r8;
	call _parametersInit;
	jump dispInputCompRatio(DB);
	m4 = gets(1);
	alter(1);

toggleInputMuteState:
	i2 = _compOnOff;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = BTGL r8 by 0, puts = r0;
	dm(m2, i2) = r8;
	call _parametersInit;
	jump dispInputMuteState(DB);
	m4 = gets(1);
	alter(1);

processOutput:

	r2 = dm(m4, i4);
	r2 = r2 + r2;
	m2 = r2;
	i2 = _output_switch_table + 1;
	i12 = dm(m2, i2);
	jump (m13, i12);

changeOutputDelay:
	r2 = _outputChannel + 20;			// output delay
	r8 = 26;
	r8 = r8 * r0(UUI), puts = r0;
	r8 = r8 + r2;
	i2 = r8;

	r8 = r8 - r8, r0 = dm(i2, m6);		// high byte first, low byte last
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m6);
	r8 = r8 OR LSHIFT r0 by 8, r0 = dm(i2, m6);
	r0 = r0 OR LSHIFT r8 by 8, r8 = dm(i2, m5);	// to be restored backwards
	r8 = r8 OR LSHIFT r0 by 8; 

	f12 = 1. / 2621.44;
	f7 = FLOAT r8;
	f7 = f7 * f12;						// percent of Max. delay time
	r8 = FIX f7;
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 99;
	r8 = MIN(r8, r4);
	f7 = FLOAT r8;
	f12 = 2621.44;
	f7 = f7 * f12;
	r8 = FIX f7;

    r4 = FEXT r8 by  0:8;
    r4 = FEXT r8 by  8:8, dm(i2, m7) = r4;
    r4 = FEXT r8 by 16:8, dm(i2, m7) = r4;
    r4 = FEXT r8 by 24:8, dm(i2, m7) = r4;
	dm(i2, m5) = r4;
 
	call _parametersInit;
	jump dispOutputDelay(DB);
	r4 = gets(1);
	alter(1);

changeOutputGain:
	i2 = _outputChannel + 18;			// CHLevel
	r8 = 26;
	r8 = r8 * r0(UUI), puts = r0;
	m2 = r8;

	r8 = dm(m2, i2);
	r8 = r8 + r4;
	r0 = 181 - 36;
	r8 = MAX(r0, r8);
	r0 = 181 + 36;
	r8 = MIN(r0, r8);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispOutputGain(DB);
	r4 = gets(1);
	alter(1);

changeOutputPEQNo:
	i2 = _adjustOutputPEQPointer;
	m2 = r0;							// last switch as PEQ No.
	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 4;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

changeOutputPEQType:
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r8 = 26;
	r8 = r8 * r0(UUI), r2 = dm(m2, i2);	// r2=0,1 for HPF, LPF
	r2 = r2 - 1, puts = r0;				// r2=2,3,4 for PEQ
	r2 = r2 + r2;						// 2 bytes for HPF and LPF
	i2 = _outputChannel + 2;			// output PEQ_type - 4
	r5 = 5;								// 5 types of PEQ
	if GT jump (pc, 3), r2 = r2 + r2;	// 4 bytes for each PEQ
	i2 = _outputChannel + 4;			// output HPF_type + 2
	r5 = 11;							// 11 types of LCF/HCF

	r8 = r8 + r2;
	m2 = r8;
	r8 = dm(m2, i2);

	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r8 = MIN(r8, r5);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispOutputPEQType(DB);
	r4 = gets(1);
	alter(1);

changeOutputPEQFreq:
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r8 = 26;
	r8 = r8 * r0(UUI), r2 = dm(m2, i2);	// r2=0,1 for HPF, LPF
	r2 = r2 - 1, puts = r0;				// r2=2,3,4 for PEQ
	r2 = r2 + r2;						// 2 bytes for HPF and LPF
	i2 = _outputChannel + 3;			// output PEQ_freq - 4
	if GT jump (pc, 2), r2 = r2 + r2;	// 4 bytes for each PEQ
	i2 = _outputChannel + 5;			// output HPF_freq + 2

	r8 = r8 + r2;
	m2 = r8;
	r8 = dm(m2, i2);

	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 122;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;
	
	call _parametersInit;
	jump dispOutputPEQFreq(DB);
	r4 = gets(1);
	alter(1);

changeOutputPEQLevel:
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r8 = 26;
	r8 = r8 * r0(UUI), r2 = dm(m2, i2);	// r2=0,1 for HPF, LPF
	r2 = r2 - 1, puts = r0;				// r2=2,3,4 for PEQ
	r2 = LSHIFT r2 by 2;				// 4 bytes for each PEQ
	if LE r4 = r4 - r4;					// case LCF/HCF, DO NOT CHANGE
	i2 = _outputChannel + 4;			// output PEQ_level - 4

	r8 = r8 + r2;
	m2 = r8;
	r8 = dm(m2, i2);

	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 48;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispOutputPEQLevel(DB);
	r4 = gets(1);
	alter(1);

changeOutputPEQQ:
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r8 = 26;
	r8 = r8 * r0(UUI), r2 = dm(m2, i2);	// r2=0,1 for HPF, LPF
	r2 = r2 - 1, puts = r0;				// r2=2,3,4 for PEQ
	r2 = LSHIFT r2 by 2;				// 4 bytes for each PEQ
	if LE r4 = r4 - r4;					// case LCF/HCF, DO NOT CHANGE
	i2 = _outputChannel + 5;			// output PEQ_Q - 4

	r8 = r8 + r2;
	m2 = r8;
	r8 = dm(m2, i2);

	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 72;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispOutputPEQQ(DB);
	r4 = gets(1);
	alter(1);

toggleOutputMuteState:
	i2 = _outputChannel + 25;			// CHMuting
	r8 = 26;
	r8 = r8 * r0(UUI), puts = r0;
	m2 = r8;

	r8 = dm(m2, i2);
	r8 = BTGL r8 by 0;
	dm(m2, i2) = r8;
	call _parametersInit;
	jump dispOutputMuteState(DB);
	r4 = gets(1);
	alter(1);

changeOutputThreshold:
	i2 = _outputChannel + 19;			// PeakLimiterThreshold
	r8 = 26;
	r8 = r8 * r0(UUI), puts = r0;
	m2 = r8;

	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 53;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispOutputThreshold(DB);
	r4 = gets(1);
	alter(1);

changeOutputLink:
	i2 = _outputChannel + 1;			// CHSource
	r8 = 26;
	r8 = r8 * r0(UUI), puts = r0;
	m2 = r8;

	r8 = dm(m2, i2);
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 2;
	r8 = MIN(r8, r4);
	dm(m2, i2) = r8;

	call _parametersInit;
	jump dispOutputLink(DB);
	r4 = gets(1);
	alter(1);

