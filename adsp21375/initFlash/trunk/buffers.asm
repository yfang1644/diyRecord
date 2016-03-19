#include "constant.h"
#include "flash.h"

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

.var _SoftwareVersion[64] = 'Ver.0.54 Mar.01 2011            ',
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
.var _programNo = 13;					// 序号
.var _programValid = 0;
.var _programRecallLock = 0;			// 调入允许
.var _programProtection = 0xff;			// 保护，禁止覆盖、擦除
.var _programOutputStatus[6] = 0x41, 0x42, 0x41, 0x42, 0x41, 0x42;
.var _programName[21] = 'System Default.......';
.var _programInfomation[256] = 'Default program.      ',
		'IN-1 -> OUT-A,B,C and IN-2 -> OUT-D,E,F. OUT-A/D = LF[-100Hz] ',
		'OUT-B/E = MF[100Hz-1kHz] OUT-C/F = HF[1kHz-] This program is  ',
		'permanently protected. .......................................',
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
//CHLevel, PeakLimiterThreshold, (CHDelay,4 bytes), CHPhase, CHMuting
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

