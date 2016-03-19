//////////////////////////////////////////////////////////////////////////////
//NAME:     panel.asm                                                       //
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

.extern _div10, ___float_divide;
.extern _inpParam;
.extern _Company, _DeviceInfo, _SoftwareVersion;
.extern _remoteID, _programNo, _panelStatus;
.extern _readFlash, _writeFlash, _programCheck;
.extern _inPower, _inComp;
.extern _tempUserData;

.extern _compOnOff, _outputChannel;
.extern _programOutputStatus;
.section/dm seg_dmda;
.var switch_jump_table[] =
		0x0b7e, MUTE_IN0,	  _MUTE_IN0,	// MAX7301 P24
		0x0b7d, MUTE_IN1,	  _MUTE_IN1,	// MAX7301 P25
		0x0b7b, MUTE_OUT0,	  _MUTE_OUT0,	// MAX7301 P26
		0x0b77, MUTE_OUT1,	  _MUTE_OUT1,	// MAX7301 P27
		0x0b6f, MUTE_OUT2,	  _MUTE_OUT2,	// MAX7301 P28
		0x0b5f, MUTE_OUT3,	  _MUTE_OUT3,	// MAX7301 P29
		0x0b3f, MUTE_OUT4,	  _MUTE_OUT4,	// MAX7301 P30
		0x0e6f, MUTE_OUT5,    _MUTE_OUT5,
		0x0e7e, SWITCH_DOWN,  _SWITCH_DOWN,
		0x0e7d, SWITCH_UP,	  _SWITCH_UP,
		0x0e7b, SWITCH_DISP,  _SWITCH_DISP,
		0x0e77, SWITCH_ENTER, _SWITCH_ENTER;

.var _dBlevel[] =
		StandardN40dB,
		StandardN20dB,
		StandardN10dB,
		StandardN6dB,
		Standard0dB;

.global _blink88, _switchInterval, _levelIndicator;
.var _blink88 = LED_FLASH_RATE;			// blink rate 50*10ms
.var _switchInterval = SWITCH_DELAY;	// limit switch speed, 0.5s
.var _levelIndicator = LEVEL_INDICATOR;

.section/dm seg_dm16;
.var _manual = 1;						// 1--uart, 2--manual
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

.global _panelCommandTable;
.var _panelCommandTable[] =			// 低位对齐
		0x4000, 0x4400, 0x4400,		// FUNC(4),       P4-10(OUT2),  P4-10( IN0)
		0x4800, 0x4b00, 0x4b00,		// ports(LED A), P11-17(OUT3), P11-17( IN1)
		0x5000, 0x5200, 0x5200,		// ports(LED B), P18-24(OUT4), P18-24(OUT0)
		0x0000, 0x5900, 0x5900,		// ports in,     P25-31(OUT5), P25-31(OUT1)
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
// 0 -- 7 (In0, In1, Out0, Out1 ... Out5)
// 8 -- ENTER
// 9 -- DISPLAY
// 10, 11 -- UP, DOWN
#define	KEY_IN0		0
#define	KEY_IN1		1
#define	KEY_OUT0	2
#define	KEY_OUT1	3
#define	KEY_OUT2	4
#define	KEY_OUT3	5
#define	KEY_OUT4	6
#define	KEY_OUT5	7
#define	KEY_ENTER	8
#define	KEY_DISPLAY	9
#define	KEY_UP		10
#define	KEY_DOWN	11

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
		nop;
		nop;
		nop;
setMax7301:
		dm(SPIFLGB) = ustat3;

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
	ustat1 = 24;						// Setup the baud rate to 13MHz
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

	bit SET FLAGS FLG8O|FLG9O;			// Enable Flag8 and Flag9 output
	bit SET ustat4 BIT_28;				// disable switch delay
	bit CLR ustat4 BIT_20|BIT_29;		// stop LED8 blinks
										// start level indicator

	bit CLR FLAGS FLG8;					// Enable panel-key input
	bit SET FLAGS FLG9;					// prepare to test UP/DONW keys

	bit SET mode2 IRQ1E;				// IRQ pins edge sensitive
	bit CLR irptl IRQ1I;
	bit CLR IMASK IRQ1I;

	call _updatePanel(DB);
	i4 = _panelInitTable;
	r4 = (@_panelInitTable + @_panelCommandTable)/3;
	r4 = r4 - r4, r0 = m5;
	CCALL (_programCheck);
	r0 = 50;							// machine ID=1~50
	comp (r2, r0);						// memory should be 0xFF in new machine
	if LE jump (pc, not_new_machine), else r4 = r4 - r4;
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_writeFlash);

not_new_machine:
	r4 = 0;
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
	CCALL (_readFlash);

	r4 = 51;
	r0 = 1;
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

	r4 = 0x10000000;
	lcntr = r4, do (pc, 1) until lce;
		nop;

	call _updatePanel(DB);
	i4 = _panelInitTable + 15;
	r4 = 1;
	r8 = dm(RXSPIB);

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
	r2 = r2 + r8;
	rts(DB);
	dm(_panelCommandTable + 6) = r2;
	dm(_digitBlackTemp + 1) = r2;
_digitDisplay00.end:

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
	i5 = _inPower;
	i12 = _inComp;						// Compressor active
	i8 = _ledtable;
	i4 = _panelCommandTable;
	r10 = 0x003f;						// N-Mute-x-x-x-x-x-Limit
	i10 = _dBlevel;
	m10 = -5;
	r4 = INS;
	r0 = OUTS;
	bit TST ustat4 BIT_29;				//BIT_29 used to display output status
	if not TF r4 = r4 + r0;
	r4 = r4 + r0;
	lcntr = r4, do level1 until lce;
		m4 = pm(i8, m14);
		r0 = dm(m4, i4);
		r0 = r0 OR r10, r8 = pm(i12, m14);	// 1 means compressor
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

	r0 = LEVEL_INDICATOR;
	dm(_levelIndicator) = r0;

	jump (pc, _updatePanel)(DB);		// eliminate RTS
	i4 = _panelCommandTable;
	r4 = 5;
_levelBlink.end:

/*
	Import: No parameter
	Changed registers: all registers
	Export: No parameter
*/
.global _keyProcessing;
_keyProcessing:
	call _updatePanel(DB);
	i4 = _panelCommandTable + 15;
	r4 = 1;

	r3 = dm(RXSPIB);

	r4 = FLAGS;

	r8 = FEXT r3 by 0:7;
	r4 = FEXT r4 by 16:4;
	r8 = r8 OR FDEP r4 by 8:4;
	i4 = switch_jump_table;
	r0 = dm(_manual);
	r3 = 3;
	r0 = r3 - r0, m2 = r0;
	m4 = r0;
	lcntr = @switch_jump_table/2, do (pc, 4) until lce;
		r10 = dm(i4, m2);
		comp(r8, r10);
		if EQ jump switch_hit(LA);
		modify(i4, m4);

	jump EndKeyPortJudge;				// switch not matched, do nothing

_keyProcessing.end:

switch_hit:
	i12 = dm(m5, i4);
	jump (m13, i12);

MUTE_IN0:								// input channel 0 settings
	r4 = KEY_IN0;
	jump _muteSwitch;

MUTE_IN1:								// input channel 1 settings
	r4 = KEY_IN1;
	jump _muteSwitch;

MUTE_OUT0:								// output channel 0
	r4 = KEY_OUT0;
	jump _muteSwitch;

MUTE_OUT1:								// output channel 1
	r4 = KEY_OUT1;
	jump _muteSwitch;

MUTE_OUT2:								// output channel 2
	r4 = KEY_OUT2;
	jump _muteSwitch;

MUTE_OUT3:								// output channel 3
	r4 = KEY_OUT3;
	jump _muteSwitch;

MUTE_OUT4:								// output channel 4
	r4 = KEY_OUT4;
	jump _muteSwitch;

MUTE_OUT5:								// output channel 5
	r4 = KEY_OUT5;
	jump _muteSwitch;

_muteSwitch:

	i4 = _panelCommandTable;
	i2 = _ledtable;
	m2 = r4;
	m4 = dm(m2, i2);
	r12 = dm(m4, i4);
	r12 = BTGL r12 by 6;
	r0 = FEXT r12 by 6:1;
	dm(m4, i4) = r12;	// MUTE light-on/off toggle

	i4 = _inpParam + 1;					// i4 -> _inpParam.mute
	r8 = 5;								// struct _inpParam 5xINS
	r8 = r8 * r4(UUI);
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
	r0 = dm(_programNo);
	dm(_disp_programNo) = r0;
	r0 = dm(_remoteID);
	dm(_disp_remoteID) = r0;
	r0 = LED_FLASH_RATE;
	dm(_blink88) = r0;
	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;				// bit1-0: Prog., Status, or RemoteID
	r0 = r0 + 1;						// panel not locked
	r2 = 3;
	comp (r0, r2);
	if GE r0 = r0 - r0;					// skip '3'
	r8 = 0x40ff;						// set LSB0-2 of IC2(P4-P6)
	r8 = BCLR r8 by r0, r4 = m5;		// Prog., Status, or RemoteID, r4=0
	dm(_panelCommandTable) = r8;
	dm(_panelStatus) = r0;

	jump __from_SWITCH_DISP;

SWITCH_ENTER:							// ENTER/RECALL KEY
	bit TGL ustat4 BIT_20;

	r0 = dm(_digitBlackTemp + 0);
	r1 = dm(_digitBlackTemp + 1);
	dm(_panelCommandTable + 3) = r0;
	dm(_panelCommandTable + 6) = r1;
	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, loadParameters), else r0 = r0 - 1;
	if EQ jump (pc, EndKeyPortJudge), else r0 = r0 - 1;
	if EQ jump (pc, saveRemoteID);

EndKeyPortJudge:
	call _updatePanel(DB);
	i4 = _panelCommandTable + 12;
	r4 = 1;								//re-enable transition detection

	r4 = SWITCH_DELAY;
	dm(_switchInterval) = r4;
	bit CLR ustat4 BIT_30|BIT_28;
	rts;								// return from key proccessing

loadParameters:
	bit TST ustat4 BIT_20;				// neccessary!
	if TF jump dispStatus;				// blinking..., display status

	r4 = dm(_disp_programNo);
	i2 = _programNo;
	r8 = _tempUserData - _programNo;
	CCALL (_readFlash);
	r4 = 51;
	i2 = _programNo;
	CCALL (_writeFlash);
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
	r4 = 1;								// -1:DOWN KEY,1:UP KEY
	jump (pc, _UP_DOWN_KEY_PROCESS);

SWITCH_DOWN:							// DOWN KEY
	r4 = -1;							// -1:DOWN KEY,1:UP KEY
	jump (pc, _UP_DOWN_KEY_PROCESS);

/*
	Import: R4(-1:DOWN KEY, +1:UP KEY), _panelStatus ...
	Used regitster:
	Export: No
*/
_UP_DOWN_KEY_PROCESS:
	bit TST ustat4 BIT_20;
	if not TF jump (pc, EndKeyPortJudge);	// not blinking, return
	r0 = dm(_panelStatus);
__from_SWITCH_DISP:
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, changeProgramNo), else r0 = r0 - 1;	// _panelState=0
	if EQ jump (pc, dispStatus), else r0 = r0 - 1;// _panelState=1
	if EQ jump (pc, changeRemoteID);	// _panelState=2
	jump EndKeyPortJudge;

dispStatus:								// _panelStatus=1
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
	r3 = pass r4;
	if EQ jump check_nothing;

	r4 = dm(_disp_programNo);
	lcntr = 50, do (pc, check_recall) until lce;
		r4 = r4 + r3, r8 = m6;
		r4 = MAX(r4, r8);				// New ProgramNo >= 1
		r8 = 50;
		r4 = MIN(r4, r8), r0 = m6;		// not greater than 50, check valid

		CCALL (_programCheck);

		r5 = pass r2, r2 = dm(2, i4);	// recall lock
		r2 = r2 OR r5;
		if EQ jump (pc, recall_valid)(LA), r8 = pass r4;
		nop;
		nop;
		nop;
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

	jump EndKeyPortJudge;

changeRemoteID:
	r8 = dm(_disp_remoteID);
	r8 = r8 + r4;
	if LE r8 = r8 - r4;					// remoteID must be POSITIVE
	r4 = 50;
	comp(r8, r4);
	if GT r8 = r4;						// remoteID <= 50
	dm(_disp_remoteID) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

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
		dispOutputCompress,	changeOutputCompress,
		dispOutputLink,		changeOutputLink;

.var _lastSwitch = -1;

.var _switchPosition[INS+OUTS+2] =
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1;
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

_MUTE_IN0:								// input channel 0 settings
	r4 = KEY_IN0;
	jump (pc, 2);

_MUTE_IN1:								// input channel 1 settings
	r4 = KEY_IN1;

	dm(_lastSwitch) = r4;
	i8 = _ledtable;
	i0 = _panelCommandTable;
	r12 = 0xff;
	lcntr = INS+OUTS, do (pc, 4) until lce;
		m1 = pm(i8, m14);
		r0 = dm(m1, i0);
		r0 = r0 OR r12;
		dm(m1, i0) = r0;				// light-off In/-dB

	i2 = _ledtable;
	m4 = r4;
	m1 = dm(m4, i2);
	r12 = dm(m1, i0);
	r12 = BCLR r12 by 6;
	dm(m1, i0) = r12;					/// light-on Mute, MUTE indication.

	i4 = _switchPosition;
	m4 = r4;
	r0 = dm(m4, i4);
	r0 = r0 + 1;
	r1 = @_input_switch_table / 2;
	comp(r0, r1);
	if GE r0 = r0 - r0;
	r0 = r0 + r0, dm(m4, i4) = r0;
	i4 = _input_switch_table;
	m4 = r0;
	i12 = dm(m4, i4);
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
	i2 = _PEQLevel;

	m2 = r4;
	r8 = dm(m2, i2);					// gain = 0.5v - 181 , v=0-205
	r0 = 181;
	r8 = r8 - r0;
	r8 = ASHIFT r8 by -1;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 2) = r0;	// light In0/-10dB

	jump EndKeyPortJudge;

dispInputPEQNo:
	i2 = _adjustInputPEQPointer;

	m2 = r4;
	r8 = dm(m2, i2);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 2) = r0;	// light In0/-20dB

	jump EndKeyPortJudge;

dispInputPEQType:
	i2 = _adjustInputPEQPointer;
	m2 = r4;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter;
	m2 = r8;
	r8 = dm(m2, i2);
	r0 = FEXT r8 by 4:4;
	r8 = FEXT r8 by 0:4;
	call _digitDisplayFF;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 2) = r0;	// light In0/-40dB

	jump EndKeyPortJudge;

dispInputPEQFreq:
	i2 = _adjustInputPEQPointer;
	m2 = r4;
	r8 = dm(m2, i2);
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
	i2 = _adjustInputPEQPointer;
	m2 = r4;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter + 2;
	m2 = r8;
	r0 = dm(m2, i2);
	r8 = 181;
	r8 = r0 - r8;
	r8 = ASHIFT r8 by -1;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 5) = r0;	// light In1/-10dB

	jump EndKeyPortJudge;

dispInputPEQQ:
	i2 = _adjustInputPEQPointer;
	m2 = r4;
	r8 = dm(m2, i2);
	r8 = LSHIFT r8 by 3;				// 2channels x 4 bytes
	r4 = LSHIFT r4 by 2;				// 4 bytes
	r8 = r8 + r4;
	i2 = _PEQParameter + 3;
	m2 = r8;
	r8 = dm(m2, i2);
	r8 = FEXT r8 by 0:8;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 5) = r0;	// light In1/-20dB
	jump EndKeyPortJudge;

dispInputThreshold:
	i2 = _compThreshold;

	m2 = r4;
	r8 = dm(m2, i2);					// dBFS = -0.5v, v=0-96
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 1;
	dm(_panelCommandTable + 2) = r0;	// light In0/Over
	jump EndKeyPortJudge;

dispInputCompRatio:
	i2 = _compRatio;

	m2 = r4;
	r8 = dm(m2, i2);					// g = 1-v/100, v=0-100
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 0;
	dm(_panelCommandTable + 2) = r0;	// light In0/Limiter
	jump EndKeyPortJudge;

dispInputMuteState:
	i2 = _compOnOff;
	m2 = r4;
	r0 = dm(m2, i2);

	r4 = dm(m1, i0);
	r4 = BSET r4 by 6;
	r0 = pass r0;
	if EQ r4 = BCLR r4 by 6;
	dm(m1, i0) = r4;

	r0 = dm(_panelCommandTable + 5);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 5) = r0;	// light In1/-40dB
	jump EndKeyPortJudge;

_MUTE_OUT0:								// output channel 0
	r4 = KEY_OUT0;
	jump outpMuteSwitch;

_MUTE_OUT1:								// output channel 1
	r4 = KEY_OUT1;
	jump outpMuteSwitch;

_MUTE_OUT2:								// output channel 2
	r4 = KEY_OUT2;
	jump outpMuteSwitch;

_MUTE_OUT3:								// output channel 3
	r4 = KEY_OUT3;
	jump outpMuteSwitch;

_MUTE_OUT4:								// output channel 4
	r4 = KEY_OUT4;
	jump outpMuteSwitch;

_MUTE_OUT5:								// output channel 5
	r4 = KEY_OUT5;

outpMuteSwitch:
	dm(_lastSwitch) = r4;

	i8 = _ledtable;
	i0 = _panelCommandTable;
	r12 = 0xff;
	lcntr = INS+OUTS, do (pc, 4) until lce;
		m1 = pm(i8, m14);
		r0 = dm(m1, i0);
		r0 = r0 OR r12;
		dm(m1, i0) = r0;				// light-off In/-dB

	i2 = _ledtable;
	m4 = r4;
	m1 = dm(m4, i2);
	r12 = dm(m1, i0);
	r12 = BCLR r12 by 6;
	dm(m1, i0) = r12;					// light-on MUTE

	i4 = _switchPosition;
	m4 = r4;
	r0 = dm(m4, i4);
	r0 = r0 + 1;
	r1 = @_output_switch_table / 2;
	comp(r0, r1);
	if GE r0 = r0 - r0;
	r0 = r0 + r0, dm(m4, i4) = r0;
	i4 = _output_switch_table;
	m4 = r0;
	r2 = INS;
	r4 = r4 - r2, i12 = dm(m4, i4);
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
	r8 = ASHIFT r8 by -1;
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 3;
	dm(_panelCommandTable + 2) = r0;	// light In0/-10dB

	jump EndKeyPortJudge;

dispOutputPEQNo:
	i2 = _adjustOutputPEQPointer;

	m2 = r4;
	r8 = dm(m2, i2);
	call _digitDisplay00;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 4;
	dm(_panelCommandTable + 2) = r0;	// light In0/-20dB

	jump EndKeyPortJudge;

dispOutputPEQType:
	i2 = _adjustOutputPEQPointer;
	m2 = r4;
	r8 = 26;
	r8 = r8 * r4(UUI), r2 = dm(m2, i2);	// r2=2,3,4 for PEQ

	r2 = r2 - 1;						// r2=0,1 for HPF, LPF
	r2 = r2 + r2;						// 2, 3, 4 for PEQ
	i2 = _outputChannel + 2;			// output PEQ_type - 4
	if GT jump (pc, 2), r2 = r2 + r2;	// 4 bytes for each PEQ
	i2 = _outputChannel + 4;			// output HPF_type + 2

	r8 = r8 + r2;
	m2 = r8;
	r8 = dm(m2, i2);
	r0 = FEXT r8 by 4:4;
	r8 = FEXT r8 by 4:4;
	call _digitDisplayFF;

	r0 = dm(_panelCommandTable + 2);
	r0 = BCLR r0 by 5;
	dm(_panelCommandTable + 2) = r0;	// light In0/-40dB
	jump EndKeyPortJudge;

dispOutputPEQFreq:
	i2 = _adjustOutputPEQPointer;
	m2 = r4;
	r8 = 26;
	r8 = r8 * r4(UUI), r2 = dm(m2, i2);	// r2=2,3,4 for PEQ

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
	i2 = _adjustOutputPEQPointer;
	m2 = r4;
	r8 = dm(m2, i2);
//	i2 = _outPEQs;
	r3 = 4;
	r8 = r8 - 1;
	if GT jump dispInputPEQLevel;
	jump dispInputPEQLevel;

dispOutputPEQQ:
	i2 = _adjustOutputPEQPointer;
	m2 = r4;
	r8 = dm(m2, i2);
//	i2 = _outPEQs;
	r3 = 4;
	r8 = r8 - 1;
	if GT jump dispInputPEQQ;
	jump dispInputPEQQ;

dispOutputMuteState:
dispOutputThreshold:
dispOutputCompress:
dispOutputLink:
	r8 = 26;
	r8 = r8 * r4(UUI);
	i4 = _outputChannel + 1;			// CHSource
	m4 = r8;
	r0 = dm(m4, i4);

	r2 = dm(_panelCommandTable + 2);
	BTST r0 by 0;				// test link bit
	if not SZ r2 = BCLR r2 by 6;
	dm(_panelCommandTable + 2) = r2;

	r2 = dm(_panelCommandTable + 5);
	BTST r0 by 1;
	if not SZ r2 = BCLR r2 by 6;
	r2 = BCLR r2 by 0;
	dm(_panelCommandTable + 5) = r2;	// light In1/-40dB
	jump EndKeyPortJudge;

_SWITCH_DISP:							// DISPLAY KEY
	bit CLR ustat4 BIT_24;				// disable indicator first
	r0 = dm(_panelStatus);
	r0 = r0 + 1;
	r0 = FDEP r0 by 0:3;
	dm(_panelStatus) = r0;
	r4 = 0x40ff;						// set LSB0-2 of IC2(P4-P6)
	BTST r0 by 2;
	if not SZ r4 = BCLR r4 by 3;		// 'Lock'
	r0 = BCLR r0 by 2;					// 'lock' affects LED
	r4 = BCLR r4 by r0;					// Progr., Status, or RemoteID
	dm(_panelCommandTable) = r4;

	r4 = 0;
	jump _UP_DOWN_KEY_PROCESS + 1;

_SWITCH_ENTER:							// ENTER/RECALL KEY
	bit TGL ustat4 BIT_20;
	bit TST ustat4 BIT_20;
	if TF jump EndKeyPortJudge;

	r0 = dm(_panelStatus);
	r1 = FDEP r0 by 0:2;
	if SZ jump (pc, loadSaveParameters), else r1 = r1 - 1;
	if EQ jump (pc, _dispStatus);
	jump (pc, _saveRemoteID);


loadSaveParameters:
	r4 = dm(_programNo);
	i2 = _inpParam;
//	r8 = TOTALPARAMETERS;
	BTST r0 by 2;
	if SZ jump (pc, saveProg);
	call _programValid;
	if NE jump (pc, 3);
	call _readFlash;
	if EQ jump EndKeyPortJudge;
	bit SET ustat4 BIT_20;
	jump EndKeyPortJudge;
saveProg:
	call _writeFlash;
	jump EndKeyPortJudge;

_dispStatus:
	bit SET ustat4 BIT_24;
	jump EndKeyPortJudge;

_saveRemoteID:
	r4 = 0;
	call _writeFlash(DB);
	i2 = _remoteID;
	r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion;
	jump EndKeyPortJudge;

_SWITCH_DOWN:
	r4 = -1;							// -1:DOWN KEY,1:UP KEY
	jump _UP_DOWN_KEY_PROCESS;

_SWITCH_UP:								// UP KEY
	r4 = 1;								// -1:DOWN KEY,1:UP KEY
	jump _UP_DOWN_KEY_PROCESS;


/*
	Import: R4(-1:DOWN KEY, +1:UP KEY), _panelStatus ...
	Used regitster: 
	Export: No
*/
__UP_DOWN_KEY_PROCESS:

	r0 = dm(_panelStatus);
	r0 = FEXT r0 by 0:2;
	if SZ jump (pc, _changeProgramNo), else r0 = r0 - 1;	// _panelState=1
	if EQ jump (pc, _changeParameters);	// _panelState=2
	jump (pc, _changeRemoteID);			// _panelState=3

_changeProgramNo:
	r8 = dm(_programNo);

	r8 = r8 + r4, r4 = m6;
	r8 = MAX(r8, r4);					//New ProgramNo >=1
	r4 = 50;							//New ProgramNo <= 50
	r8 = MIN(r8, r4);
	dm(_programNo) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

_changeParameters:
	bit TST ustat4 BIT_20;				// digits are blinking
	if not TF jump EndKeyPortJudge;
	i4 = _switchPosition;
	r0 = dm(_lastSwitch);
	m4 = r0;
	r1 = INS;
	comp(r0, r1);
	if GE jump processOutput;

//	r5 = _inp_coeffs;
//	dm(_pCoeff) = r5;
//	r5 = _inp_segmentGain;
//	dm(_pGain) = r5;

//	i14 = _inp_segmentGain;
//	i15 = _inp_PEQLevel;				// for _updateAllGain(DB);

	r2 = dm(m4, i4);
	r2 = r2 + r2;
	m2 = r2;
	i2 = _input_switch_table + 1;
	i12 = dm(m2, i2);
	jump (m13, i12);

changeInputDelay:
	i3 = _inpParam;						// share with change output delay

	r3 = 5;								// struct _inpParam = INSx5
	r3 = r3 * r0(UUI);					// r0 = channel No.(incl. INS and OUTS)
	m3 = r3;
	r8 = dm(m3, i3);
	f12 = 1. / 2621.44;
	f7 = FLOAT r8;
	f7 = f7 * f12;						// percent of Max. delay time
	r8 = FIX f7;
	r8 = r8 + r4, r4 = m5;
	r8 = MAX(r8, r4);
	r4 = 99;
	r8 = MIN(r8, r4);
	f7 = FLOAT r8, r3 = r8;
	f12 = 2621.44;
	f7 = f7 * f12;
	r8 = FIX f7;
	r8 = pass r3, dm(m3, i3) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

changeInputGain:
//	i2 = _inputGainDB;					// share with change output gain
//	i3 = _inpParam + 1;

	r3 = 5;
	m2 = r0;
	r3 = r3 * r0(UUI);					// r0=channel no.(incl. INS and OUTS)
	m3 = r3;
	r8 = dm(m2, i2);
	r8 = r8 + r4;
	r4 = -176;
	comp(r8, r4);
	if LT r8 = r4;
	r4 = 24;
	comp(r8, r4);
	if GT r8 = r4;				// gain = -88 ~ +12dB
	f7 = FLOAT r8, dm(m2, i2) = r8;
	r8 = ASHIFT r8 by -1;
	call _digitDisplay00;
//	call (pc, _expf)(DB);
	f12 = 2.30258509299404590109/40.0;	//ln(10)/40
	f4 = f7 * f12;
	dm(m3, i3) = f0;
	jump EndKeyPortJudge;

changeInputPEQNo:
	r2 = IN_PEQS;
changeInputPEQNo1:						// share with input PEQ pointer
	i2 = _adjustInputPEQPointer;
	m2 = r0;							// last switch as PEQ No.
	r8 = dm(m2, i2);
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	comp(r8, r2);
	if GE r8 = r2 - 1;
	dm(m2, i2) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;

changeInputPEQType:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r3 = IN_PEQS;
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	dm(_index) = r8;
//	i3 = _inPEQs;
	m3 = r8;
	r1 = dm(m3, i3);
	r0 = FEXT r1 by 28:4;
	r8 = FEXT r1 by 24:4;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 5;							// 5 types of PEQ
	comp(r8, r4);
	if GT r8 = r4;
	r4 = FEXT r1 by 0:24;
	r4 = r4 OR LSHIFT r0 by 28;
	r4 = r4 OR LSHIFT r8 by 24;
	dm(m3, i3) = r4;
	call _digitDisplayFF;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
//	r4 = INS;
//	r5 = IN_PEQS;
	jump EndKeyPortJudge;

changeInputPEQFreq:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r3 = IN_PEQS;
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	dm(_index) = r8;
//	i3 = _inPEQs;
	m3 = r8;
	r1 = dm(m3, i3);
	r8 = FEXT r1 by 16:8;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 120;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xff00ffff;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 16;
	dm(m3, i3) = r4;
	r0 = FEXT r8 by 4:4;
	r8 = FEXT r8 by 0:4;
	call _digitDisplayFF;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
//	r4 = INS;
//	r5 = IN_PEQS;
	jump EndKeyPortJudge;

changeInputPEQLevel:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r3 = IN_PEQS;
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	dm(_index) = r8;
//	i3 = _inPEQs;
	m3 = r8;
	r1 = dm(m3, i3);
	r8 = FEXT r1 by 8:8(SE);		// 0.5dB/div
	r8 = r8 + r4;
	r4 = 24;						// +12dB
	comp(r8, r4);
	if GT r8 = r4;
	r4 = -24;						// -12dB
	comp(r8, r4);
	if LT r8 = r4;
	r4 = 0xffff00ff;
	r4 = r4 AND r1;
	r0 = FEXT r8 by 0:8;
	r4 = r4 OR FDEP r0 by 8:8;
	dm(m3, i3) = r4;
	r8 = FEXT r4 by 9:7(SE);		// r8 = FEXT r0 by 8:0 for 0.5dB
	call _digitDisplay00;

//	call _calculatePEQ;
//	call _updateAllGain(DB);
	r4 = INS;
	r5 = IN_PEQS;
	jump EndKeyPortJudge;

changeInputPEQQ:
	i2 = _adjustInputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r3 = IN_PEQS;
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	dm(_index) = r8;
//	i3 = _inPEQs;
	m3 = r8;
	r1 = dm(m3, i3);
	r8 = FEXT r1 by 0:8;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 72;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xffffff00;
	r4 = r4 AND r1;
	r4 = r4 OR r8;
	dm(m3, i3) = r4;
	call _digitDisplay00;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
	r4 = INS;
	r5 = IN_PEQS;
	jump EndKeyPortJudge;

changeInputThreshold:
//	i2 = _inputThresholdDB;				// share with change output threshold
//	i3 = _inpParam + 3;

	r3 = 5;
	r3 = r3 * r0(UUI);					// r0=channel no.(incl. INS and OUTS)
	m2 = r0;
	m3 = r3;
	r8 = dm(m2, i2);
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 40;
	comp(r8, r4);
	if GT r8 = r4;						// min. threshold -40dB(0.01)
	f7 = FLOAT r8, dm(m2, i2) = r8;
	call _digitDisplay00;
//	call (pc, _expf)(DB);
	f12 = -2.30258509299404590109/40.0;	//ln(10)/40
	f4 = f7 * f12;
	dm(m3, i3) = f0;
	jump EndKeyPortJudge;

changeInputCompRatio:
//	i2 = _inputCompressRatio;			// share with change output compress
//	i3 = _inpParam + 4;

	r3 = 5;
	r3 = r3 * r0(UUI);					// r0=channel no.(incl. INS and OUTS)
	m2 = r0;
	m3 = r3;
	r8 = dm(m2, i2);
	r8 = r8 + r4;
	if LE r8 = m6;
	r4 = 40;
	comp(r8, r4);
	if GT r8 = r4;						// min. threshold -40dB(0.01)
	call (pc, ___float_divide)(DB);
	f12 = FLOAT r8, dm(m2, i2) = r8;
	f7 = 1.0;
	call _digitDisplay00;
	dm(m3, i3) = f7;
	jump EndKeyPortJudge;

toggleInputMuteState:
	i3 = _inpParam + 2;					// share with output mute change

	r3 = 5;
	r3 = r3 * r0(UUI);
	m3 = r3;
	r8 = dm(m3, i3);
	r8 = BTGL r8 by 0;
	dm(m3, i3) = r8;

	i2 = _ledtable;
	m2 = r2;
	r2 = dm(m2, i2);
	i3 = _panelCommandTable;
	m3 = r2;
	r4 = dm(m3, i3);
	r4 = BCLR r4 by 6;
	r4 = r4 OR LSHIFT r8 by 6;
	dm(m3, i3) = r4;

	jump EndKeyPortJudge;

processOutput:
//	r5 = _outp_coeffs;
//	dm(_pCoeff) = r5;
//	r5 = _outp_segmentGain;
//	dm(_pGain) = r5;

//	i14 = _outp_segmentGain;
//	i15 = _outp_PEQLevel;			// for _updateAllGain(DB);

	r2 = dm(m4, i4);
	r2 = r2 + r2;
	m2 = r2;
	i2 = _output_switch_table + 1;
	i12 = dm(m2, i2);
	jump (m13, i12);

changeOutputDelay:
changeOutputGain:
changeOutputPEQNo:
	r2 = 5;							// 0-HP, 1-LP, 2~4 for PEQ
	jump changeInputPEQNo1;

changeOutputPEQType:
	r1 = INS;
	r0 = r0 - r1;
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r3 = OUT_PEQS;
	r3 = r3 * r0(UUI);				// r3 = 9*chn
	r8 = dm(m2, i2);
	r8 = r8 - 1;
	if LT jump crossoverType1;
	if EQ jump crossoverType2;
	r5 = 5;							// r8 = 1~3
	r5 = r5 + r8;					// r5 = 6-8
	r5 = r5 + r3;
//	dm(_index) = r5;
	r3 = 4;							// struct outPEQs = OUTSx4
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	i4 = _outPEQs;
	m4 = r8;
	r1 = dm(m4, i4);
	r0 = FEXT r1 by 28:4;
	r8 = FEXT r1 by 24:4;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 5;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xf0ffffff;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 24;
	dm(m4, i4) = r4;
	call _digitDisplayFF;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

crossoverType1:
//	dm(_low_pass) = m7;				// high pass
//	dm(_index) = r3;
	r3 = 4;							// struct outPEQs=OUTSx4
	r3 = r3 * r0(UUI);
	m4 = r3;
//	i4 = _outPEQs;
	r1 = dm(m4, i4);
	r0 = FEXT r1 by 28:4;
	r8 = FEXT r1 by 24:4;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 12;						// 12 types of crossover
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xf0ffffff;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 24;
	dm(m4, i4) = r4;
	r4 = lshift r4 by -16;
	call _digitDisplayFF;
//	call _calculateCrossover;		// HPF
//	call _updateAllGain(DB);
//	r4 = OUTS;
//	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

crossoverType2:
//	dm(_low_pass) = m6;				// low pass
	r1 = 3;
	r3 = r3 + r1;					// r3 = 9*chn+3
//	dm(_index) = r3;
	r3 = 4;
	r3 = r3 * r0(UUI);
	m4 = r3;
//	i4 = _outPEQs;
	r1 = dm(m4, i4);
	r0 = FEXT r1 by 12:4;
	r8 = FEXT r1 by 8:4;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 12;						// 12 types of crossover
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xfffff0ff;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 8;
	dm(m4, i4) = r4;
	call _digitDisplayFF;
//	call _calculateCrossover;		// LPF
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

changeOutputPEQFreq:
	r1 = INS;
	r0 = r0 - r1;
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r3 = OUT_PEQS;
	r3 = r3 * r0(UUI);				// r3 = 9*chn
	r8 = dm(m2, i2);
	r8 = r8 - 1;
	if LT jump crossoverFreq1;
	if EQ jump crossoverFreq2;
	r5 = 5;							// r8 = 1~3
	r5 = r5 + r8;					// r5 = 6-8
	r5 = r5 + r3;
//	dm(_index) = r5;
	r3 = 4;							// struct outPEQs = OUTSx4
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	i4 = _outPEQs;
	m4 = r8;
	r1 = dm(m4, i4);
	r8 = FEXT r1 by 16:8;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 120;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xff00ffff;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 16;
	dm(m4, i4) = r4;
	call _digitDisplay00;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

crossoverFreq1:
//	dm(_low_pass) = m7;				// high pass
//	dm(_index) = r3;
	r3 = 4;
	r3 = r3 * r0(UUI);
	m4 = r3;
//	i4 = _outPEQs;
	r1 = dm(m4, i4);
	r8 = FEXT r1 by 16:8;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 120;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xff00ffff;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 18;
	dm(m4, i4) = r4;
	call _digitDisplay00;
	r4 = lshift r4 by -16;
//	call _calculateCrossover;		// HPF
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

crossoverFreq2:
//	dm(_low_pass) = m6;				// low pass
	r1 = 3;
	r3 = r3 + r1;
//	dm(_index) = r3;
	r3 = 4;
	r3 = r3 * r0(UUI);
	m4 = r3;
//	i4 = _outPEQs;
	r1 = dm(m4, i4);
	r8 = FEXT r1 by 0:8;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 120;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xffffff00;
	r4 = r4 AND r1;
	r4 = r4 OR LSHIFT r8 by 2;
	dm(m4, i4) = r4;
	call _digitDisplay00;
//	call _calculateCrossover;		// LPF
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

changeOutputPEQLevel:
	r1 = INS;
	r0 = r0 - r1;
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = r8 - 1;
	if LE jump EndKeyPortJudge;
	r3 = OUT_PEQS;
	r3 = r3 * r0(UUI);				// struct outpparamet = OUTSx9
	r5 = 5;							// r8 = 1~3
	r5 = r5 + r8;					// r5 = 6~8
	r5 = r5 + r3;
//	dm(_index) = r5;
	r3 = 4;							// struct outPEQs = OUTSx4
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	i4 = _outPEQs;
	m4 = r8;
	r1 = dm(m4, i4);
	r8 = FEXT r1 by 8:8(SE);		// 0.5dB/div
	r8 = r8 + r4;
	r4 = 24;						// +12dB
	comp(r8, r4);
	if GT r8 = r4;
	r4 = -24;						// -12dB
	comp(r8, r4);
	if LT r8 = r4;
	r4 = 0xffff00ff;
	r4 = r4 AND r1;
	r0 = FEXT r8 by 0:8;
	r4 = r4 OR LSHIFT r0 by 8;
	dm(m4, i4) = r4;
	r8 = FEXT r4 by 9:7(SE);		// r8 = FEXT r0 by 8:0 for 0.5dB
	call _digitDisplay00;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

changeOutputPEQQ:
	r1 = INS;
	r0 = r0 - r1;
	i2 = _adjustOutputPEQPointer;
	m2 = r0;
	r8 = dm(m2, i2);
	r8 = r8 - 1;
	if LE jump EndKeyPortJudge;
	r3 = OUT_PEQS;
	r3 = r3 * r0(UUI);				// struct outpparamet = OUTSx9
	r5 = 5;							// r8 = 1~3
	r5 = r5 + r8;					// r5 = 6~8
	r5 = r5 + r3;
//	dm(_index) = r5;
	r3 = 4;							// struct outPEQs = OUTSx4
	r3 = r3 * r0(UUI);
	r8 = r8 + r3;
//	i4 = _outPEQs;
	m4 = r8;
	r1 = dm(m4, i4);
	r8 = FEXT r1 by 0:8;
	r8 = r8 + r4;
	if LT r8 = r8 - r8;
	r4 = 72;
	comp(r8, r4);
	if GT r8 = r4;
	r4 = 0xffffff00;
	r4 = r4 AND r1;
	r4 = r4 OR r8;
	dm(m4, i4) = r4;
	call _digitDisplay00;
//	call _calculatePEQ;
//	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;
	jump EndKeyPortJudge;

toggleOutputMuteState:
changeOutputThreshold:
changeOutputCompress:
changeOutputLink:
//	i3 = _crossLink - INS;
	m4 = r0;
	r8 = dm(m4, i3);

	r8 = r8 + r4;
	if LE r8 = r8 - r8;
	r4 = (1 << INS) - 1;
	comp(r8, r4);
	if GE r8 = r4;
	dm(m4, i3) = r8;

	r2 = dm(_panelCommandTable + 2);
	r2 = BSET r2 by 6;					// lid Mute0
	BTST r8 by 0;						// test link bit
	if not SZ r2 = BCLR r2 by 6;
	dm(_panelCommandTable + 2) = r2;

	r2 = dm(_panelCommandTable + 5);
	r2 = BSET r2 by 6;					// lid Mute0
	BTST r8 by 1;
	if not SZ r2 = BCLR r2 by 6;
	dm(_panelCommandTable + 5) = r2;

	jump EndKeyPortJudge;

_changeRemoteID:
	r8 = dm(_remoteID);
	r8 = r8 + r4;
	r1 = 1;
	comp (r8, r4);
	if LT r8 = r4;					// RemoteID > 1
	r4 = 50;
	comp(r8, r4);
	if GT r8 = r4;					// RemoteID < 50
	dm(_remoteID) = r8;
	call _digitDisplay00;
	jump EndKeyPortJudge;
