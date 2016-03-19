//////////////////////////////////////////////////////////////////////////////
//NAME:     processing.asm                                                  //
//DATE:     2010-11-20                                                      //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.global _samples, _inp_buf, _outp_buf;
.extern _outputChannel, _inpParam, _outpParam, _compressorGain;
.extern _peqGain;
.extern _inp_coeffs, _outp_coeffs;
.extern _inp_segmentGain, _outp_segmentGain;
.extern _inPower, _outPower;
.extern _inp_states, _outp_states;
.extern _sineFreq, _sineLvl, _noiseLvl;
.extern _inputSource;
.extern ___float_divide;

.section/dm seg_dmda;

.var  _samples[OUTS] = 0x1234, 0x5678, 0x4321, 0x8765, 0xaaaa, 0xbbbb;
.var  _inp_buf[OUTS] = 0x1234, 0x5678, 0x4321, 0x8765, 0xaaaa, 0xbbbb;
.var _outp_buf[OUTS] = 0x1234, 0x5678, 0x4321, 0x8765, 0xaaaa, 0xbbbb;

.var _freqTablePointer[INS] = 0, 0;
.var _seed = 0xd2441440;

// Xpeak , keep maximum value for output channel processing
.var _Xpeak[OUTS] = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0;

.section/pm seg_pmco;

/*****************************************************************
 * input equalizer and output equalzer IIR biquad filtering
 * input equalizer should be called just after ADC
 * then copy input buffer to output buffer
 * then call output equalizer
 *
 * m1 = 2;
 * DO NOT USE r2/f2
 *****************************************************************/
_EQualizer:
	i10 = _inp_buf;

	i4 = i10;
	f8 = pm(i10, m14);
	lcntr = r5, do AudioProcessing_PEQ until lce;
		r12 = r12 - r12, f1 = dm(i1, m6), f4 = pm(i8, m14);
		lcntr= r6, do (pc, 4) until lce;
			f12 = f1 * f4, f8 = f8 + f12, f3 = dm(i1, m7), f4 = pm(i8, m14);
			f12 = f3 * f4, f8 = f8 + f12, dm(i1, m1) = f3, f4 = pm(i8, m14);
			f12 = f1 * f4, f8 = f8 + f12, f1 = dm(i1, m7), f4 = pm(i8, m14);
			f12 = f3 * f4, f8 = f8 + f12, dm(i1, m1) = f8, f4 = pm(i8, m14);
		f8 = f8 + f12, modify(i8, m15);
AudioProcessing_PEQ:
		dm(i4, m6) = f8, f8 = pm(i10, m14);

	rts;
_EQualizer.end:

/*
{ Cascaded IIR Biquad Sections
  (Direct Form II or Transposed Direct Form I)

      w(n) = x(n) + a1*w(n-1) + a2*w(n-2)       beware of signs here!
      y(n) = w(n) + b1*w(n-1) + b2*w(n-2)       (single biquad structure)

                        -1       -2
                1 + b1 z   + b2 z
       H(z) = -----------------------
                        -1       -2
                1 - a1 z   - a2 z

  Each section consists of: b2,b1,a2,a1,w(n-1),w(n-2)
  Notice that coefs have been normalized such that b0=1.0

  Benchmark
    6 + 4*(sections) cycles     cascaded_biquad

  Memory Usage
    --- cascaded_biquad ---
    10 words        instructions in PM
    4*(sections)    coefficients in PM
    2*(sections)    delay line storage in DM
}
*/
//  { --- comments for subroutine called cascaded_biquad ---               }
//  {TERMINOLOGY: w' = w(n-1), w" = w(n-2), NEXT = "of next biquad section"}
//  { #1    clear f12,            rd w",       rd a2         loop prologue }
//  { #2    for each section, do:                                          }
//  { #3    w"a2, 1st=x+0,else=y, rd w',       rd a1         loop body     }
//  { #4    w'a1, x+w"a2,         wr new w',   rd b2         loop body     }
//  { #5    w"b2, new w,          rd NEXT w",  rd b1         loop body     }
//  { #6    w'b1, new w+(w"b2),   wr new w,    rd NEXT a2    loop body     }
//  { #7    calc last y after dropping out of loop           loop epilogue }

/**********************************************************************
 * compressor and limiter for the inputs after PEQ for current samples
 * (WITHOUT DEALY)
 *
 * i4: _inpParam(delay, mute, gain, threshold, compress ratio, comp on)
 * i10: _inp_buf
 *********************************************************************/
_BufferInput:
	i10 = _inp_buf;
	i4 = _inpParam + 1;
	i12 = _compressorGain;
	lcntr = INS, do buffer1 until lce;
		r7 = dm(i4, m6), f8 = pm(i10, m13);		// r7=mute, f8=input
		r8 = r8 AND r7, f10 = dm(i4, m6);		// f7=(float)mute,f10=gain
		f8 = f8 * f10, f0 = dm(i4, m6), f9 = pm(i12, m14);
					// f0=threshold, f9=compress gain
		f10 = ABS f8, f1 = dm(i4, m6);			// f1=compress ratio
		f7 = f10 - f0, dm(i4, m5) = m14;		// compressor as default
		if GT jump(pc, 4)(DB), f7 = f7 * f1;
		f7 = f7 + f0;
		f8 = f7 COPYSIGN f8;
		dm(i4, m5) = m13;						// no compressor(0)
		f8 = f8 * f9, modify(i4, m6);
buffer1:
		f10 = dm(i4, m6), pm(i10, m14) = f8;	// skip DELAY item

	rts;
_BufferInput.end:


/*********************************************************************
 * route input channel 0/1 to input buffer 0-5 according to _crosslink
 * crossLink:
 *		0: (IN1+IN2)/2
 *		1:  IN1
 *		2:	IN2
 *		others: 0(no input)
 * Input: f0=channel0(no delay), f1=channel1(no delay) 
 *********************************************************************/
_RouteInput:
//	i10 = _inp_buf;
	i3 = _array_in1;
	r4 = dm(_inpParam + 0);						// delay input channel 0
	r4 = r15 - r4;
	r4 = FEXT r4 by 0:MSB;
	m4 = r4;
	r4 = dm(_inpParam + 6);						// delay input channel 1
	r4 = r15 - r4, f8 = dm(m4, i3);				// f8=delayed channel0
	i4 = _outputChannel + 1;					// outputChannel->CHSource
	m2 = 26;									// i4 modifier
	r4 = FEXT r4 by 0:MSB, r6 = dm(i4, m2);
	m4 = r4;
	modify(i3, m0);
	r2 = r2 - r2, f9 = dm(m4, i3);				// f9=delayed channel 1
	lcntr = OUTS, do route1 until lce;
		r6 = r6 - 1;							// r6 can be 0,1,2 or 3
		if LT jump (pc, route1), f2 = (f0 + f1)/2;
		if EQ jump (pc, route1), f2 = PASS f8;
		r6 = r6 - 1;
		if EQ f2 = PASS f9;
route1:
		r2 = r2 - r2, r6 = dm(i4, m2), pm(i10, m14) = f2;
	rts;
_RouteInput.end:


/*******************************************************************
 *AGC, similar to compress and limiter
 *
 * i4: _outpParam(delay, gain, mute, threshold, compress ratio
 * f0: compress ratio
 * f1: threshold
 * r15: processing pointer
 * r4: delay
 * r13: 23, shift float to integer
 * i3: output buffer
 *******************************************************************/
_OutputProcessing:
	i3 = _array_out0;
	i10 = _outp_buf;
	i4 = _outpParam;
	i11 = _outPower;
	i12 = _Xpeak;
	f6 = 1.0;							// alpha, p = alpha*x^2 + (1-alpha)*p
	f5 = 0.0;							// 1 - alpha
	r13 = 31;							// 2^{31}, for DACs [-1, +1) saturate
	r4 = dm(i4, m6);					// r4=delay
	bit set MODE1 ALUSAT;				// FIX instruction needs saturation
	lcntr = OUTS, do (pc, _out1) until lce;
		r4 = r15 - r4, r8 = dm(i4, m6);			// r8=mute(0:mute)
		r4 = FDEP r4 by 0:MSB;
		m3 = r4;
		f4 = dm(m3, i3);						// f4=x
		r8 = r4 AND r8, f12 = dm(i4, m6), f10 = pm(i12, m13);	// f12=gain, f10=Xpeak
		f8 = f8 * f12, f7 = dm(i4, m6);			// f7=threshold
		f12 = ABS f8, f1 = dm(i4, m6);			// f12=|x|, f1=ReleaseFrac
		comp(f12, f10), dm(i4, m5) = m13;		// default no compressor(0)
		if LT f12 = f10 * f1;
		comp(f12, f7), pm(i12, m14) = f12;		// |Xpeak|>threshold?, restore Xpeak
		if LT jump (pc, 3);
		call (pc, ___float_divide);
		f8 = f8 * f7, dm(i4, m5) = m14;			// compressor(1)
		f1 = f8 * f8, modify(i4, m6);			// f1=x^2
		r12 = FIX f8 by r13, r10 = dm(i3, m0), pm(i11, m14) = f1;	// outPower=x*x
		r12 = ASHIFT r12 by -8;					// DAC 24bits
_out1:
		r4 = dm(i4, m6), pm(i10, m14) = r12;

	r15 = r15 + 1;
	r15 = FEXT r15 by 0:MSB;
	rti(DB);
	bit clr MODE1 SRRFL|SRRFH|SRD1H|SRD1L|SRD2H|SRD2L;
	POP STS, FLUSH CACHE;
_OutputProcessing.end:

// static Word16 seed = 21845;
// *seed = extract_l(L_add(L_shr(L_mult(*seed, 31821), 1), 13849L));
_Random:
	r4 = dm(_seed);
	r2 = 1664525;
	r6 = ASHIFT r4 by -8;
	r4 = r4 * r2(SSI);
	r2 = 32767;
	r4 = r4 + r2;
	rts(DB), r4 = r4 + r6;
	dm(_seed) = r4;
	f4 = FLOAT r4 by r13;
_Random.end:


//   +----------------<---------------O<------+
//   |                                ^       ^
//   |                                |       |  
//   |                                |       |
//   +--> a0 ---> a1 ---> a2 ---> a3 -+-> a4 -+----->  s(n)
//      O == XOR, N=31 produce periodic noise

_max_length_sequence:
	r4 = dm(_seed);
	r4 = r4 + r4, r2 = r4;
	r2 = r2 XOR r4;
	r2 = r2 + r2;
	r2 = r2 + r2;
	r4 = r4 + CI;
	dm(_seed) = r4;
	r4 = FEXT r4 by 31:1;
	rts(DB), r4 = r4 + r4;
	r4 = r4 - 1;
	f4 = FLOAT r4;			// return 1.0 or -1.0
_max_length_sequence.end:

.global _digitalProcessing;
_digitalProcessing:
	i2 = _inputSource;
	i3 = _sineTable;
	i4 = _samples;
	i5 = _sineFreq;

	i8 = _sineLvl;
	i9 = _peqGain;
	i10 = _inp_buf;
	i11 = _inPower;
	i12 = _freqTablePointer;
	f6 = 1.0;							// alpha, p = alpha*x^2+ (1-alpha)*p
	f5 = 0.0;							// 1 - alpha
	r13 = -31;							// 2^{-23}, for normalizing [-1, +1)
	lcntr = INS, do (pc, digit_P1) until lce;
	// get SOURCE
		r0 = dm(i2, m6), f10 = pm(i8, m14);
								// r0=source type(0, 1, 2), f10=sine level
		r4 = dm(i4, m6), f12 = pm(i9, m14);
								// analog input & channel gain
		r0 = r0 - 1, r1 = dm(i5, m6), r0 = pm(i12, m13);
								// r1=sine frequency step, r2 = pointer
		if LT jump (pc, source_analog);	// analog input
		if GT jump (pc, source_sine), r0 = r0 + r1;
		call (pc, _Random);
		f10 = dm(_noiseLvl);
		jump (pc, digit_P2), f4 = f4 * f10;
source_sine:
		r0 = FEXT r0 by 0:MSB;
		m4 = r0;
		f4 = dm(m4, i3);
		jump (pc, digit_P2), f4 = f4 * f10; // already floating

source_analog:
		r4 = LSHIFT r4 by 8;

	// convert input samples(ananog, noise or sine) to floating point,
	// calculate powers of input series, save to inp_buf
		f4 = FLOAT r4 by r13;
digit_P2:
		f4 = f4 * f12, pm(i12, m14) = r0;
		f12 = f4 * f4, pm(i10, m14) = f4;	// save to inp_buf
digit_P1:
		pm(i11, m14) = f12;					// save input power 

//---------------------------------------------------------------

	i1 = _inp_states;					// for input delay line buffer
	i8 = _inp_coeffs;					// for coefficent buffer
	call _EQualizer(DB);
	r5 = INS;
	r6 = IN_PEQS;

	call _BufferInput;

	i10 = _inp_buf;						// i10 keeps unchaned until next call
//	DMA transfer
	dm(DMAC0) = m5;						// disable DMA
	r4 = _array_in1;
	dm(IIEP0) = i10;
	r4 = r4 + r15, f0 = pm(i10, m14);
	dm(EIEP0) = r4;						// external memory index
	r4 = INS;
	dm(ICEP0) = r4;						// internal memory counter
	r4 = DEN|TRAN;						// Enable DMA, one shoot
	dm(DMAC0) = r4;
	f1 = pm(i10, m15);					// f0, f1 as current channel input
										// may be directly used in RouteInput
//-------------------------------------*/

/*	Normal transfer
	i3 = _array_in1;
	m3 = r15;
	modify(i3, m3);
	f0 = pm(i10, m14);
	dm(i3, m0) = f0, f1 = pm(i10, m15);	//i10 keep unchanged
	dm(i3, m0) = f1;					// f0=channel 0, f1=channel 1
										// may be directly used in RouteInput
//---------------------------------*/

	call _RouteInput;

	i1 = _outp_states;					// for output delay line buffer
	i8 = _outp_coeffs;					// for coefficent buffer
	call _EQualizer(DB);				// output equalizer
	r5 = OUTS;
	r6 = OUT_PEQS;

	i10 = _inp_buf;
//	DMA transfer
	dm(DMAC0) = m5;						// disable DMA
	r4 = _array_out0;
	r4 = r4 + r15;
	dm(EIEP0) = r4;
	r4 = OUTS;
	dm(ICEP0) = r4;						// internal memory counter
	dm(IIEP0) = i10;
	r4 = DEN|TRAN;						// Enable DMA, one shoot
	dm(DMAC0) = r4;
//---------------------------------------*/

/*	Normal transfer
	i3 = _array_out0;
	m3 = r15;
	modify(i3, m3);
	f4 = pm(i10, m14);
	lcntr = OUTS, do (pc, 1) until lce;
		dm(i3, m0) = f4, f4 = pm(i10, m14);
//---------------------------------*/
	jump _OutputProcessing;

_digitalProcessing.end:


