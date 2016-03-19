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

.extern _inp_coeffs, _outp_coeffs;
.extern _inp_segmentGain, _outp_segmentGain;
.extern _inPower, _outPower;
.extern _inp_states, _outp_states;
.extern _sineFreq, _sineLvl;
.extern ___float_divide;

.section/dm seg_dmda;

.var  _samples[OUTS] = 0, 0, 0, 0, 0, 0;
.var  _inp_buf[OUTS] = 0, 0, 0, 0, 0, 0;
.var _outp_buf[OUTS] = 0, 0, 0, 0, 0, 0;

.var _freqTablePointer[INS] = 0, 0;

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
 * i4: _inpParam(delay, mute, gain, threshold, compress ratio)
 * i10: _inp_buf
 *********************************************************************/
_BufferInput:

	i10 = _inp_buf;
	i4 = _inpParam + 1;
	i2 = _compressorGain;
	lcntr = INS, do buffer1 until lce;
		r7 = dm(i4, m6), f8 = pm(i10, m13);	//r7=mute, f8=input
		f7 = FLOAT r7, f10 = dm(i4, m6);//f7=(float)mute,f10=gain
		f7 = f7 * f10, f0 = dm(i4, m6);	//f0=threshold
		f8 = f8 * f7, f1 = dm(i4, m6);	//f1=compress ratio
		f10 = ABS f8, f9 = dm(i2, m6);
		f7 = f10 - f0, dm(i4, m5) = m14;// compressor as default
		if GT jump(pc, 4)(DB), f7 = f7 * f1;
		f7 = f7 + f0;
		f8 = f7 COPYSIGN f8;
		dm(i4, m5) = m13;				// no compressor(0)
		f8 = f8 * f9, modify(i4, m6);
buffer1:
		f10 = dm(i4, m6), pm(i10, m14) = f8;// skip DELAY item

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
	i3 = _array;
	r4 = dm(_inpParam + 0);				//delay input channel 0
	r4 = r15 - r4;
	r4 = FEXT r4 by 0:MSB;
	m4 = r4;
	r4 = dm(_inpParam + 6);				//delay input channel 1
	r4 = r15 - r4, f8 = dm(m4, i3);		//f8=delayed channel0
	i4 = _outputChannel + 1;			// outputChannel->CHSource
	m2 = 26;							// i4 modifier
	r4 = FEXT r4 by 0:MSB, r6 = dm(i4, m2);
	m4 = r4;
	modify(i3, m0);
	r2 = r2 - r2, f9 = dm(m4, i3);		//f9=delayed channel 1
	lcntr = OUTS, do route1 until lce;
		r6 = r6 - 1;					//r6 can be 0,1,2 or 3
		if LT jump (pc, route1), f2 = (f0 + f1)/2;
		if EQ jump (pc, route1), f2 = pass f8;
		r6 = r6 - 1;
		if EQ f2 = pass f9;
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
	i3 = _array + MAXBUFFER * INS;
	i10 = _outp_buf;
	i4 = _outpParam;
	i11 = _outPower;
	i12 = _Xpeak;
	f6 = 1.0;							// alpha, p = alpha*x^2+ (1-alpha)*p
	f5 = 0.0;							// 1 - alpha
	r13 = 23;							// 2^{23}, for DACs [-1, +1)
	r2 = 0x3f7fffff;					// clipping
	r4 = dm(i4, m6);					//r4=delay
	lcntr = OUTS, do (pc, _out1) until lce;
		r4 = r15 - r4, r14 = dm(i4, m6);	//r14=mute(0:mute)
		r4 = FDEP r4 by 0:MSB, f10 = dm(i4, m6);//f10=gain
		f14 = FLOAT r14, m3 = r4;
		f14 = f14 * f10, f8 = dm(m3, i3);	//f8=x
		f8 = f8 * f14, f7 = dm(i4, m6), f9 = pm(i12, m13);
					//f7=threshold, f9=Xpeak
		f12 = ABS f8, f1 = dm(i4, m6), f3 = pm(i11, m13);
					//f12=|x|, f1=ReleaseFrac, f3=OutPower
		comp(f12, f9), dm(i4, m5) = m13;	// no compressor(0) as default
		if LT f12 = f9 * f1;
		comp(f12, f7), pm(i12, m14) = f12;
					// |Xpeak|>threshold?  , restore Xpeak
		if LT jump (pc, 4);
		call (pc, ___float_divide);
		f8 = f8 * f7;
		dm(i4, m5) = m14;				// compressor(1)
		f3 = f3 * f5, modify(i4, m6);
		f1 = f8 * f8, modify(i3, m0);
		f8 = CLIP f8 by f2;
		f10 = f1 * f6, r12 = fix f8 by r13;
		f3 = f3 + f10, pm(i10, m14) = r12;
_out1:
		r4 = dm(i4, m6), pm(i11, m14) = f3;

	r15 = r15 + 1;
	r15 = FEXT r15 by 0:MSB;
	rti(DB);
	bit clr MODE1 SRRFL|SRRFH|SRD1H|SRD1L|SRD2H|SRD2L;
	POP STS, FLUSH CACHE;
_OutputProcessing.end:


_audioProcessing:
	i4 = _samples;
	i10 = _inp_buf;
	i11 = _inPower;
	f6 = 1.0;							// alpha, p = alpha*x^2+ (1-alpha)*p
	f5 = 0.0;							// 1 - alpha
	r13 = -23;							// 2^{-23}, for normalizing [-1, +1)
	r8 = dm(i4, m6);
	lcntr = INS, do (pc, _audioP1) until lce;
		r8 = FDEP r8 by 0:24(SE), f3 = pm(i11, m13);
		f3 = f3 * f5, f8 = float r8 by r13;
		f12 = f8 * f8, pm(i10, m14) = f8;
		f4 = f12 * f6;
		f3 = f3 + f4;
_audioP1:
		r8 = dm(i4, m6), pm(i11, m14) = f12;

_audioP2:
	m1 = 2;								// for _EQualizer, unchanged

	i1 = _inp_states;					// for input delay line buffer
	i8 = _inp_coeffs;					// for coefficent buffer
	call _EQualizer(DB);
	r5 = INS;
	r6 = IN_PEQS;

	call _BufferInput;

	i10 = _inp_buf;						// i10 keeps unchaned until next call
//	DMA transfer
	dm(DMAC0) = m5;						// disable DMA
	r4 = _array;
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
	i3 = _array;
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
	r4 = _array + INS * MAXBUFFER;
	r4 = r4 + r15;
	dm(EIEP0) = r4;
	r4 = OUTS;
	dm(ICEP0) = r4;						// internal memory counter
	dm(IIEP0) = i10;
	r4 = DEN|TRAN;						// Enable DMA, one shoot
	dm(DMAC0) = r4;
//---------------------------------------*/

/*	Normal transfer
	i3 = _array + INS * MAXBUFFER;
	m3 = r15;
	modify(i3, m3);
	f4 = pm(i10, m14);
	lcntr = OUTS, do (pc, 1) until lce;
		dm(i3, m0) = f4, f4 = pm(i10, m14);
//---------------------------------*/
	jump _OutputProcessing;

_audioProcessing.end:


.global _digitalProcessing;
_digitalProcessing:
	bit TST ustat4 BIT_10;
	if not TF jump _audioProcessing;
	i4 = _sineTable;
	i5 = _sineFreq;
	i8 = _sineLvl;
	i10 = _inp_buf;
	i11 = _inPower;
	i12 = _freqTablePointer;
	lcntr = INS, do (pc, digital_L0) until lce;
		r1 = dm(i5, m6), r2 = pm(i12, m13);
		r1 = r1 + r2;
		r1 = FEXT r1 by 0:MSB, f4 = pm(i8, m14);
		m4 = r1;
		f8 = dm(m4, i4);
		f8 = f8 * f4, pm(i12, m14) = r1;
		f13 = f8 * f8, pm(i10, m14) = f8;
digital_L0:
		pm(i11, m14) = f13;

	jump _audioP2;
_digitalProcessing.end:

