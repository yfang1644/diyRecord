#include "constant.h"
#include "flash.h"

.global _inp_states, _outp_states;
.global _inp_coeffs, _outp_coeffs;
.global _inp_segmentGain, _outp_segmentGain;

.section/dm seg_dmda;
/*
.var GEQFrequencyTable[] =		// 1/3oct. 频率表，数值加倍(20H-20k)---UNUSED
	   40,    50,    63,    80,   100,   125,   160,   200,   250,   315,
	  400,   500,   630,   800,  1000,  1250,  1600,  2000,  2500,  3150,
	 4000,  5000,  6300,  8000, 10000, 12500, 16000, 20000, 25000, 32000,
	40000;

.global _FrequencyTable;
.var _FrequencyTable[] =				// 1/12 oct.
	   20.0,    21.2,    22.4,    23.7,    25.0,
	   26.5,    28.0,    29.7,    31.5,    33.5,
	   35.5,    37.5,    40.0,    42.5,    45.0,
	   47.4,    50.0,    53.0,    56.0,    59.5,
	   63.0,    67.0,    71.0,    75.0,    80.0,
	   85.0,    90.0,    95.0,   100.0,   106.0,
	  112.0,   118.0,   125.0,   132.0,   140.0,
	  150.0,   160.0,   170.0,   180.0,   190.0,
	  200.0,   212.0,   224.0,   237.0,   250.0,
	  265.0,   280.0,   297.0,   315.0,   335.0,
	  355.0,   375.0,   400.0,   425.0,   450.0,
	  474.0,   500.0,   530.0,   560.0,   595.0,
	  630.0,   670.0,   710.0,   750.0,   800.0,
	  850.0,   900.0,   950.0,  1000.0,  1060.0,
	 1120.0,  1180.0,  1250.0,  1320.0,  1400.0,
	 1500.0,  1600.0,  1700.0,  1800.0,  1900.0,
	 2000.0,  2120.0,  2240.0,  2370.0,  2500.0,
	 2650.0,  2800.0,  2970.0,  3150.0,  3350.0,
	 3550.0,  3750.0,  4000.0,  4250.0,  4500.0,
	 4740.0,  5000.0,  5300.0,  5600.0,  5950.0,
	 6300.0,  6700.0,  7100.0,  7500.0,  8000.0,
	 8500.0,  9000.0,  9500.0, 10000.0, 10600.0,
	11200.0, 11800.0, 12500.0, 13200.0, 14000.0,
	15000.0, 16000.0, 17000.0, 18000.0, 19000.0,
	20000.0;
//	x = 20*pow(2, i/12);	i=0....120

.global _QTable;
.var _QTable[] =
	 0.31,  0.32,  0.34,  0.36,  0.39,  0.41,  0.43,  0.46,  0.49,  0.52,
	 0.55,  0.58,  0.61,  0.65,  0.69,  0.73,  0.77,  0.82,  0.87,  0.92,
	 0.97,  1.03,  1.09,  1.15,  1.22,  1.29,  1.37,  1.45,  1.54,  1.63,
	 1.73,  1.83,  1.94,  2.05,  2.17,  2.30,  2.44,  2.58,  2.73,  2.90,
	 3.07,  3.25,  3.44,  3.65,  3.86,  4.09,  4.33,  4.59,  4.86,  5.15,
	 5.46,  5.78,  6.12,  6.48,  6.87,  7.27,  7.71,  8.16,  8.65,  9.16,
	 9.70, 10.30, 10.90, 11.50, 12.20, 12.90, 13.70, 14.50, 15.40, 16.30,
	17.30, 18.30, 19.40;
//	x = pow(10.0, (i - 0.5)/40.0); i=-20...+52
*/
// input delay, mute(compressor on/off), gain(各级PEQ增益累积xPEQLevel),
//				threshold, compress ratio, compress on(1--compress)
.global _inpParam, _outpParam;
.var _inpParam[INS*6] =		// compress ratio=1. no distortion
		0, 1, 1.1, 1.0, 1.0, 0,
		0, 1, 1.1, 1.0, 1.0, 0;

// output delay, mute, gain(各级PEQ增益累积), threshold, compress ratio, comp
.var _outpParam[OUTS*6] =	//0.999929 ~ 220ms
		0, 1, 1.1, 0.5, 0.999929, 0,
		0, 1, 1.1, 0.5, 0.999929, 0,
		0, 1, 1.1, 0.5, 0.999929, 0,
		0, 1, 1.1, 0.5, 0.999929, 0,
		0, 1, 1.1, 0.5, 0.999929, 0,
		0, 1, 1.1, 0.5, 0.999929, 0;

.global _attackTime, _releaseTime;

.var _attackTime[INS+OUTS];
// attack time(in second)  =0.00001*exp(10, i/12), i=0,...60
.var _releaseTime[INS+OUTS];
// release time(in second) =0.00100*exp(10, i/12), i=0,...48

.global _compressorGain;
.var _compressorGain[INS] = 60.0, 60.0;	// based compGain

// 滤波器系数.biquad直接II型: a2,a1,b2,b1...
//	w(n) = x(n) + a1*w(n-1) + a2*w(n-2)       beware of signs here!
//	y(n) = w(n) + b1*w(n-1) + b2*w(n-2)       (single biquad structure)
//
//	                  -1       -2
//	          1 + b1 z   + b2 z
//	 H(z) = -----------------------
//	                  -1       -2
//	          1 - a1 z   - a2 z

.var _inp_coeffs[INS*4*IN_PEQS];			// PEQ coeffs of input
.var _outp_coeffs[OUTS*4*OUT_PEQS];			// PEQ coeffs of output

.var _inp_segmentGain[INS*IN_PEQS] =		// individual gains of PEQ
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0;

.var _outp_segmentGain[OUTS*OUT_PEQS] =
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0;

.global _sineFreq, _sineLvl;
.var _sineFreq[INS] = 4032, 4032;		// 正弦表中步长(1000Hz@65kHz)
.var _sineLvl[INS] = 1.0, 1.0;

// input and output power, for level display, compressor active
.global _inPower, _outPower;
.var _inPower[INS] = 0.0, 0.0;
.var _outPower[OUTS] = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0;

.section/pm seg_pmda;
// 滤波延迟线  w(n-2),w(n-1)...
.var _inp_states[INS*2*(IN_PEQS+1)];	// input PEQ states
.var _outp_states[OUTS*2*(OUT_PEQS+1)];	// output PEQ states

.var _uart_txbuf[UART_BUF_SIZE];
.section/dm seg_dm16;
//----------------------------------
// 以下写入ID sector
//----------------------------------
.global _remoteID;
.var _remoteID = 1;

.global _Company, _DeviceInfo, _SoftwareVersion, _panelStatus;
.var _Company[16] = 'ELDER AUDIO     ';
.var _DeviceInfo[256] =
		'EC2600 on ADI-21375                                             ',
		'                                                                ',
		'                                                                ',
		'                                                                ';

.var _SoftwareVersion[64] = 'Ver.0.54 Mar.02 2011            ',
							'                                ';
.var _panelStatus = 0;			// Program->Status->Remote->Program...
								// bit2: panelLock(1=lock)

//----------------------------------
// 以下写入各sector,参数

/*******************************************************
// Structure of 4-byte parametric equalizer data
typedef struct
{
	unsigned char      Type;
	unsigned char      Freq;
	unsigned char      Level;
	unsigned char      Q;
}structPEQ;

// Structure of 26-byte output channel data
typedef struct
{
	unsigned char      CHLink;
	unsigned char      CHSource;
	unsigned char      HPFType;
	unsigned char      HPFFreq;
	unsigned char      LPFType;
	unsigned char      LPFFreq;
	structPEQ          CHPEQ[3];
	unsigned char      CHLevel;
	unsigned char      PeakLimiterThreshold;
	unsigned long      CHDelay;
	unsigned char      CHPhase;
	unsigned char      CHMuting;
}structOutputCHParam;

// Structure of 648-byte program data
*********************************************************/

.global _programNo, _programValid, _programRecallLock, _programProtection;
.global _programOutputStatus;
.global _programName;
.global _programInfomation;

.global _sourceSelect;
.global _generatorSelect;
.global _pinkNoiseLevel;
.global _sineFrequency;
.global _sineLevel;
.global _generatorMuting;
.global _InputSelect;
.global _EQMode;
.global _GEQLink;
.global _GEQOnOff;
.global _GEQParameter;
.global _GEQLevel;
.global _PEQLink;
.global _PEQOnOff;
.global _PEQParameter;

.global _PEQLevel;
.global _compLinkMode;
.global _compOnOff;
.global _compEQ;
.global _compAttack;
.global _compRelease;
.global _compThreshold;
.global _compRatio;
.global _compGain;
.global _masterDelay;
.global _outputChannel;


// Data irrelevant to signal processing(287 bytes)
.var _programNo = 1;					// 序号
.var _programValid = 0;					// 0-valid, 0xff-not valid
.var _programRecallLock = 0;			// 调入允许(0-recallable, 0xff-not recallable)
.var _programProtection = 0xff;			// 保护，禁止覆盖、擦除(0-protected,0xff-not protected)
.var _programOutputStatus[6] = 0x41, 0x42, 0x41, 0x42, 0x41, 0x42;
.var _programName[21] = 'Default Preset.......';
.var _programInfomation[256] = 'Default program.      ',
		'IN-1 -> OUT-A,C,E and IN-2 -> OUT-B,D,F. OUT-A/B = LF[-100Hz] ',
		'OUT-C/D = MF[100Hz-1kHz] OUT-E/F = HF[1kHz-]. This program is ',
		'not protected. ...............................................',
		'...........................................[End]';

// Data related to signal processing
.var _sourceSelect = 0;					// 0:input, 1:generator
.var _generatorSelect = 1;				// 0:pinknoise, 1:sine wave
.var _pinkNoiseLevel = 181;				// NOT IMPLEMENTED
.var _sineFrequency = 69;				// 1kHz
.var _sineLevel = 181;					// 0dB
.var _generatorMuting = 1;				// 0:mute, 1:active
.var _InputSelect[9];					// UNKNOWN
.var _EQMode = 1;						// PEQ + Compressor
.var _GEQLink;
.var _GEQOnOff[INS] = 0, 0;
.var _GEQParameter[31*INS];
.var _GEQLevel[INS];

.var _PEQLink = 0;						// link off
.var _PEQOnOff[INS] = 1, 1;				// PEQ ON
.var _PEQParameter[4*IN_PEQS*INS] = // IN0, IN1, IN0, IN1,...
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e;
.var _PEQLevel[INS] = 181, 181;

.var _compLinkMode = 0;
.var _compOnOff[INS] = 0, 0;			// as input mute(1=mute)
.var _compEQ[4*INS] = 0x00, 0x45, 0x18, 0x2e, 0x00, 0x45, 0x18, 0x2e;
.var _compAttack[INS] = 28, 28;			// 2.2ms
.var _compRelease[INS] = 28, 28;		// 220ms
.var _compThreshold[INS] = 0, 0;		// 0dB (000~096 as 0~-48dB)
.var _compRatio[INS] = 0, 0;			// 1.0 ( a = 1- VVV/100.0)
.var _compGain[INS] = 181, 181;
.var _masterDelay[INS*4] = 0,0,0,0, 0,0,0,0;	// 8bit x 4 for each, MSB First
//CHLink, CHSource, (HPFType HPFFreq LPFType LPFFreq CHPEQ[3])
//CHLevel, PeakLimiterThreshold, (CHDelay,4 bytes), CHPhase, CHMuting(0-mute)
.var _outputChannel[OUTS*26] =
		0x20, 01, 0, 0, 0, 122, 0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 181, 0, 0,0,0,0, 0, 1,	//A
		0x10, 02, 0, 0, 0, 122, 0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 181, 0, 0,0,0,0, 0, 1,	//B
		0x08, 01, 0, 0, 0, 122, 0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 181, 0, 0,0,0,0, 0, 1,	//C
		0x04, 02, 0, 0, 0, 122, 0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 181, 0, 0,0,0,0, 0, 1,	//D
		0x02, 01, 0, 0, 0, 122, 0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 181, 0, 0,0,0,0, 0, 1,	//E
		0x01, 02, 0, 0, 0, 122, 0, 0x45, 0x18, 0x2e, 0, 0x45, 0x18, 0x2e,
		0, 0x45, 0x18, 0x2e, 181, 0, 0,0,0,0, 0, 1;	//F
.global _tempUserData;
.var _tempUserData[800];

.global _uart_rxbuf, _uart_txbuf;
.var _uart_rxbuf[UART_BUF_SIZE];

