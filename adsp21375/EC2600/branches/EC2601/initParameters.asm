//////////////////////////////////////////////////////////////////////////////
//NAME:     initParameters.asm                                              //
//DATE:     2010-11-10                                                      //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"
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

.extern _calculatePEQ;
.extern _calculateCrossover;
.extern _expf, _exp_dB, _sinf;

.extern _inDelay, _outDelay;
.extern _inpParam, _outpParam, _compressorGain;
.extern _peqGain;
.extern _inp_coeffs, _outp_coeffs;
.extern _inp_segmentGain, _outp_segmentGain;
.extern _inp_states, _outp_states;
.extern _sineFreq, _sineLvl;

.extern _pCoeff, _pGain, _index, _low_pass;
.extern _ledtable, _panelCommandTable;

.extern _attackTime, _releaseTime;

.section/dm seg_dm16;
.var _statusLevel[] = 29, 57, 69;

.section/dm seg_pmda;
.var _inp_coeffs0[INS*4*IN_PEQS];			// coefficients backups
.var _outp_coeffs0[OUTS*4*OUT_PEQS];		// coefficients backups

.section/pm seg_pmco;

_updateAllGain:
// 各级滤波器增益累积
// r4=channels, r5=orders
// used register:
//		f1 = 1.0
//		f0 copy from f1
//		i14 -> gains
//		i15 -> \prod of gains for each channel
	f1 = 1.0;
	f0 = pass f1, f2 = pm(i14, m14);
	lcntr = r4, do updateGain2 until lce;
		lcntr = r5, do (pc, 1) until lce;
			f0 = f0 * f2, f2 = pm(i14, m14);
updateGain2:
		f0 = pass f1, pm(i15, 6) = f0;

	rts;
_updateAllGain.end:


_inputPEQsInit:
	i2 = _inp_coeffs0;
	dm(_pCoeff) = i2;
	i2 = _inp_segmentGain;
	dm(_pGain) = i2;
	i10 = _PEQParameter;
	r5 = r5 - r5;
	puts = r5;
	lcntr = IN_PEQS, do peqinit1 until lce;
		i2 = _PEQOnOff;
		lcntr = INS, do peqinit2 until lce;
			dm(_index) = r5;
			r5 = dm(i2, m6), r0 = pm(i10, m14);
			r5 = pass r5, r4 = pm(i10, m14);
			if EQ r0 = r0 - r0;
			r4 = r4 OR LSHIFT r0 by 8, r0 = pm(i10, m14);
			r0 = r0 OR LSHIFT r4 by 8, r4 = pm(i10, m14);
			r4 = r4 OR LSHIFT r0 by 8;
			CCALL (_calculatePEQ);
			r5 = dm(_index);
			r3 = IN_PEQS;
peqinit2:
			r5 = r5 + r3;
		r5 = gets(1);
		r5 = r5 + 1;
peqinit1:
		dm(m6, i7) = r5;

	alter(1);
	i14 = _inp_segmentGain;
	i15 = _inpParam + 2;		//_inpParam.gain
	call _updateAllGain(DB);
	r4 = INS;
	r5 = IN_PEQS;

	rts;
_inputPEQsInit.end:


_outputPEQsInit:
	i2 = _outp_coeffs0;
	dm(_pCoeff) = i2;
	i2 = _outp_segmentGain;
	dm(_pGain) = i2;
	i2 = _outputChannel;				// CHLink, m2=26
	r5 = r5 - r5;
	lcntr = OUTS, do peqinit3 until lce;
		dm(_index) = r5;
		r0 = dm(i2, m2);
		r0 = LSHIFT r0 by 26;			// eliminate leading 26 bits
		r0 = LEFTZ r0;
		r1 = 26;
		r0 = r0 * r1(UUI);
		r1 = _outputChannel + 2;		// crossover HPF/LPF
		r0 = r0 + r1;
		i10 = r0;
		r0 = pm(i10, m14);
		r4 = pm(i10, m14);
		r4 = r4 OR LSHIFT r0 by 8;
		dm(_low_pass) = m7;				// m7 always be -1
		CCALL (_calculateCrossover);	// crossover HPF
		r5 = dm(_index);
		r3 = 3;
		r5 = r5 + r3, r0 = pm(i10, m14);
		r4 = pm(i10, m14);
		r4 = r4 OR LSHIFT r0 by 8;
		dm(_index) = r5;
		dm(_low_pass) = m6;				// m6 always be +1
		CCALL (_calculateCrossover);	// crossover LPF
		r5 = dm(_index);
		r3 = 3;
		r5 = r5 + r3;
		lcntr = OUT_PEQS - 6, do peqinit4 until lce;
			dm(_index) = r5;
			r0 = pm(i10, m14);
			r4 = pm(i10, m14);
			r4 = r4 OR LSHIFT r0 by 8, r0 = pm(i10, m14);
			r0 = r0 OR LSHIFT r4 by 8, r4 = pm(i10, m14);
			r4 = r4 OR LSHIFT r0 by 8;
			CCALL (_calculatePEQ);
			r5 = dm(_index);
peqinit4:
			r5 = r5 + 1;
peqinit3:
		nop;

	i14 = _outp_segmentGain;
	i15 = _outpParam + 2;
	call _updateAllGain(DB);
	r4 = OUTS;
	r5 = OUT_PEQS;

	rts;
_outputPEQsInit.end:


.global _parametersInit;
_parametersInit:
	call _inputPEQsInit;
	m2 = 26;
	call _outputPEQsInit;

	i10 = _inp_coeffs0;
	i2 = _inp_coeffs;

	r4 = pm(i10, m14);
	lcntr = 4*INS*IN_PEQS + 4*OUTS*OUT_PEQS, do (pc, 1) until lce;
		dm(i2, m6) = r4, r4 = pm(i10, m14);

//----------------------------------- DELAY ---------------------------------
	m10 = 6;							// m2=26
	i2 = _masterDelay;					// copy input delay
	i10 = _inpParam;
	i4 = _inDelay;						// adjust delay
	lcntr = INS, do (pc, init_delay_input) until lce;
		r0 = r0 - r0, r4 = dm(i2, m6);	// MSB first
		r4 = r4 OR LSHIFT r0 by 8, r0 = dm(i2, m6);
		r0 = r0 OR LSHIFT r4 by 8, r4 = dm(i2, m6);
		r4 = r4 OR LSHIFT r0 by 8, r0 = dm(i2, m6);
		r0 = r0 OR LSHIFT r4 by 8, r1 = dm(i4, m6);		// 4 bytes
		r0 = r0 + r1;
init_delay_input:
		pm(i10, m10) = r0;
		
	i2 = _outputChannel;				// CHLink
	i3 = _outDelay;
	lcntr = OUTS, do init_delay_output until lce;
		r0 = dm(i2, m2);
		r0 = LSHIFT r0 by 26;			// eliminate leading 26 bits
		r0 = LEFTZ r0;
		r1 = 26;
		r0 = r0 * r1(UUI);
		r1 = _outputChannel + 20;		// output delay
		r0 = r0 + r1;
		i4 = r0;
		r0 = r0 - r0, r4 = dm(i4, m6);	// MSB first
		r4 = r4 OR LSHIFT r0 by 8, r0 = dm(i4, m6);
		r0 = r0 OR LSHIFT r4 by 8, r4 = dm(i4, m6);
		r4 = r4 OR LSHIFT r0 by 8, r0 = dm(i4, m6);
		r0 = r0 OR LSHIFT r4 by 8, r1 = dm(i3, m6);		// 4 bytes
		r0 = r0 + r1;
init_delay_output:
		pm(i10, m10) = r0;

//------------------------------- PEQ total GAIN ---------------------------
	i2 = _PEQLevel;						// calculate input PEQ level
	i10 = _peqGain;						// i10->peqGain
	r3 = 181;
	lcntr = INS, do (pc, init_gain_input) until lce;
		r0 = dm(i2, m6);
		r4 = r0 - r3;
		f4 = FLOAT r4,
		CCALL (_exp_dB);					// R3 not used in expf()
		nop;
init_gain_input:
		pm(i10, m14) = f0;

	i10 = _outpParam + 2;				// i10->_outpParam.gain,r3=181
	i2 = _outputChannel;				// CHLink
	lcntr = OUTS, do (pc, init_gain_output) until lce;
		r0 = dm(i2, m2), f6 = pm(i10, m13);
		r0 = LSHIFT r0 by 26;			// eliminate leading 26 bits
		r0 = LEFTZ r0;
		r1 = 26;
		r0 = r0 * r1(UUI);
		r1 = _outputChannel + 18;		// output PEQ level
		r0 = r0 + r1;
		i4 = r0;
		r0 = dm(i4, 6);
		r4 = r0 - r3, r13 = dm(i4, m5);	// r13=PHASE
		f4 = FLOAT r4,
		CCALL (_exp_dB);
		r13 = PASS r13;
		if NE f0 = -f0;
		f0 = f0 * f6;
init_gain_output:
		pm(i10, m10) = f0;

//---------------------------------- MUTE ----------------------------------
	i8 = _ledtable;
	i4 = _panelCommandTable;

	i2 = _compOnOff;					// copy compOn/Off as mute
	i10 = _inpParam + 1;
	lcntr = INS, do (pc, init_mute_input) until lce;	// 1=IN-mute
		m4 = pm(i8, m14);
		r8 = dm(m4, i4);				// load panelCommand
		r8 = BCLR r8 by 6, r0 = dm(i2, m6);	// default MUTE-light
		r0 = r0 - 1;
		if NE r8 = BSET r8 by 6;		// set not MUTE(r0==0)
		if NE r0 = m7;
		pm(i10, m10) = r0;
init_mute_input:
		dm(m4, i4) = r8;

	i2 = _outputChannel + 25;			// outputChannel->mute
//	i10 = _outpParam + 1;
	lcntr = OUTS, do (pc, init_mute_output) until lce;	// 0=OUT-mute
		m4 = pm(i8, m14);
		r8 = dm(m4, i4);				// load panelCommand
		r8 = BCLR r8 by 6, r0 = dm(i2, m2);	// default MUTE-light
		r0 = pass r0;
		if NE r8 = BSET r8 by 6;		// set not MUTE(r0!=0)
		if NE r0 = m7;
		pm(i10, m10) = r0;
init_mute_output:
		dm(m4, i4) = r8;

//-------------------------------COMPRESSOR GAIN----------------------------
	i2 = _compGain;
	i10 = _compressorGain;
	r3 = 181;
	lcntr = INS, do (pc, pinit10) until lce;
		r0 = dm(i2, m6);
//		r0 = r0 - r3;
		r0 = r0 - r0;
		f4 = FLOAT r0,
		CCALL (_exp_dB);				// 30dB ~ -\inf dB
		nop;							//!!needed
pinit10:
		pm(i10, m14) = f0;

//------------------------ COMPRESSOR AND THRESHOLD -------------------------
	i2 = _compThreshold;				// compressor threshold(input)
	i10 = _inpParam + 3;
	lcntr = INS, do (pc, init_compressor_input) until lce;
		r0 = dm(i2, m6);
		r0 = -r0;
		f4 = FLOAT r0,
		CCALL (_exp_dB);				// 0dB ~ -48dB
		nop;
init_compressor_input:
		pm(i10, m10) = f0;

	i2 = _outputChannel;				// CHLink
	lcntr = OUTS, do (pc, init_compressor_output) until lce;
		r0 = dm(i2, m2);
		r0 = LSHIFT r0 by 26;			// eliminate leading 26 bits
		r0 = LEFTZ r0;
		r1 = 26;
		r0 = r0 * r1(UUI);
		i4 = _outputChannel + 19;		// outputChannel->PeakLimiter
		m4 = r0;
		r0 = dm(m4, i4);
		r0 = r0 - 1;					// set any big number as no limiter
		f4 = 10000000.0;				// set a big number as no limiter
		if LT jump (pc, init_compressor_output), f0 = pass f4;
		r0 = -r0;
		f4 = FLOAT r0,
		CCALL (_exp_dB);
		f1 = 1.2589254;
		f0 = f0 * f1;					// 2-0.5(x-1)dB,20*log10(1.2589)=2
init_compressor_output:
		pm(i10, m10) = f0;


	i2 = _compRatio;					// input compressor ratio
	i10 = _inpParam + 4;
	f2 = 1.0;
	f12 = 0.01;
	lcntr = INS, do (pc, init_ratio_input) until lce;
		r0 = dm(i2, m6);
		f0 = FLOAT r0;
		f0 = f0 * f12;
		f0 = f2 - f0;					// gain= 1.0-x/100.0
		if LT r0 = r0 - r0;
init_ratio_input:
		pm(i10, m10) = f0;

//---------- Crossover ranges for frontpanel display --------------------		
	i2 = _outputChannel;
	i4 = _programOutputStatus;
	i1 = _statusLevel;					// frequency index:29, 57, 69
	r10 = 0x00bb;						// 1-Mute-SLF-LF-MF-HF-IN2-IN1
	r3 = 26;
	r5 = _outputChannel;
// bit 1-0: IN1/IN0 status
// bit 2 HF(>=1000Hz)
// bit 3 MF(500-1000Hz)
// bit 4 LF(100-500Hz)
// bit 5 SLF(<=100Hz)
// HF/MF/LF/SLF四个灯全亮,表示 HPF和LPF都处于OFF状态下.
	lcntr = OUTS, do (pc, status_set_done) until lce;
		r0 = dm(i2, m5);
		r0 = LSHIFT r0 by 26;           // eliminate leading 26 bits
		r0 = LEFTZ r0;
		r0 = r0 * r3(UUI);
		r0 = r0 + r5;
		i3 = r0;

		r0 = pass r10, r4 = dm(1, i2);	// CHSource
		r4 = pass r4, r8 = dm(3, i3);	// r8 = LCF
		if EQ r4 = FEXT r10 by 4:2;		// r4 = 3;
		r0 = r0 - r4, r2 = dm(i1, m6);	// IN1/IN2 in bit1-0
		comp (r8, r2), r2 = dm(i1, m6);
		if LE r0 = BCLR r0 by 5;		// LCF<29
		comp (r8, r2), r2 = dm(i1, m7);
		if LE r0 = BCLR r0 by 4;		// LCF<57
		comp (r8, r2), r8 = dm(5, i3);	// r8 = HCF
		if LE r0 = BCLR r0 by 3;		// LCF<69
		comp (r8, r2), r2 = dm(i1, m7);
		if LT r0 = BSET r0 by 2;		// HCF<69
		comp (r8, r2), r2 = dm(i1, m5);
		if LT r0 = BSET r0 by 3;		// HCF<57
		comp (r8, r2), r2 = dm(25, i2);	// r2 = mute
		if LT r0 = BSET r0 by 4;		// HCF<29
		comp (r8, r4), modify(i2, m2);
		if LE r0 = BSET r0 by 5;		// HCF<=LCF
		r0 = r0 OR LSHIFT r2 by 6;

status_set_done:
		dm(i4, m6) = r0;
//--------------------------------------------------------


//-------------------- COMPRESSOR ATTACK AND RELEASE ----------------------
// attackFrac = 1 - expf(-1/(FS*attackTime)) 
// releaseFrac = 1 - expf(-1/(FS*releaseTime))
// considering calculation, set attackFrac and releaseFrac as:
// attackFrac = expf(-1/(FS*attackTime)) 
// releaseFrac = expf(-1/(FS*releaseTime))

	i2 = _compAttack;
	i10 = _attackTime;
	f10 = -1.0 / FS;
	f5 = -2.30258509299404590109/12.0;	// 1/attackTime
	f3 = 0.00001;						// 0.00001*pow(10, i/12), i=0,...60
	lcntr = INS, do (pc, init_attack_time) until lce;
		r4 = dm(i2, m6);
		f4 = FLOAT r4;
		f4 = f5 * f4,
		CCALL (_expf);
		f0 = f0 * f3;					//f0=1/attackTime
		f4 = f0 * f10,
		CCALL (_expf);
		pm(i10, m14) = f0;
init_attack_time:
		nop;

	i2 = _compRelease;
	i10 = _releaseTime;
	f3 = 0.001;							// 0.001*pow(10, i/12), i=0,...48
	lcntr = INS, do (pc, init_release_time) until lce;
		r4 = dm(i2, m6);
		f4 = FLOAT r4;
		f4 = f5 * f4,
		CCALL (_expf);
		f0 = f0 * f3;					//f0=1/releaseTime
		f4 = f0 * f10,
		CCALL (_expf);
		pm(i10, m14) = f0;
init_release_time:
		nop;

	rts;
_parametersInit.end:


// Put one cycle of sine wave in SDRAM, buffer length=MAXBUFFER
// For a certain sine wave frequency, the step in this buffer
// should be:
// dx = freq * MAXBUFFER / Sampling_frequency
//
.global _initSineTable;
_initSineTable:
	i2 = _sineTable;
	r10 = r10 - r10;					// f6, f3, r10 not used in _sinf()
	f3 = 2 * PI / MAXBUFFER;
	lcntr = m0, do (pc, sinetable1) until lce;
		f4 = PASS f10, 
		CCALL (_sinf);
		nop;
sinetable1:
		f10 = f10 + f3, dm(i2, m6) = f0;

	rts;
_initSineTable.end:

