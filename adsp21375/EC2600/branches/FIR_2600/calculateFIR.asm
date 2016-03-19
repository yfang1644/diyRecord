//////////////////////////////////////////////////////////////////////////////
//NAME:     calculateFIR.asm                                                //
//DATE:     2015-04-13                                                      //
//     	    Phase focused                                                   //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.extern _sinf, _cosf, ___float_divide;
.extern _readFlash;

.section/dm seg_pmda;
.var _predefinedPhase[(INS+1)*N_OCTAVE] =
#include "initialphase.h"

.var _recipsFreq[N_OCTAVE];				// save 1/(w1-w0)

.var _sin0;

.global _HexPhaseData;
.var _HexPhaseData[N_OCTAVE*2+10];

.section/dm seg_dmda1;
.global _FIR_coeffs0;
.var _FIR_coeffs0[2*FIR_N+1];	// channel 0
.var _FIR_coeffs1[2*FIR_N+1];	// channel 1
.var _FIR_coeffs2[2*FIR_N+1];	// channel 2
.var _FIR_coeffs3[2*FIR_N+1];	// channel 3

.section/pm seg_pmco;
/*
   _sinf/_cosf,      f0 = cosf(f4), f2, f8, f12 changed
   ___float_divide   f7=f7/f12, f0 changed

	f1 = omega0;
	f3 = omega1;
	f5 = phase0;
	f9 = phase1;

	/  jc(w)                1     
	| e      cos(nw)dw = ------- sin((n+k)w+ph), c(w) = k*w+ph
	/                     n + k
         1
    = ------- [sin((n+k)*w1+b)-sin((n+k)*w0+b)], b=-kw0+phase0
        n+k
         1
    = ------- [sin(n*w1+phase1)-sin(n*w0+phase0)]
        n+k
    

		if k==0:   cos(n*w0+phase0)*(w1-w0)
 */
.global _calculateFIR;
/*
	r4 = channel (0, 1)
*/
_calculateFIR:
	i8  = _predefinedPhase;
	m8  = r4;
	modify(i8, m8);                     // predefinedPhase[chn]
	r8  = @_FIR_coeffs0;
	r6  = r4 * r8 (UUI);
	i5  = _FIR_coeffs0;
	m3  = r6;
	modify(i5, m3);                     // _FIR_coeffs[]

	i2  = i5;
	i10 = i2;
	r0  = r0 - r0, modify(i10, m14);
	lcntr = FIR_N, do (pc, 1) until lce;
		dm(i2, m2) = r0, pm(i10, m10) = r0;		// m2=m10=2
	dm(i2, m2) = r0;					// clear 2*FIR_x+1

	r6  = FIR_N;
	i2  = i5;							// coeffs
	f13 = 1.0E-06;						// epsilon
	m3  = 3;
	m8  = 3;
	lcntr = 2*FIR_N+1, do (pc, calFIR_1) until lce;
		i3 = i8;						// i3->phase
		i10 = _predefinedPhase + 2;		// i10->frequency list
		i1 = _recipsFreq;				// i1->1/(w1-w0)
		f1 = 0.0;
		f14 = FLOAT r6, f9 = dm(i3, m5);
		f4 = PASS f9,
		CCALL (_sinf);
		dm(_sin0) = f0;

		lcntr = N_OCTAVE, do (pc, calFIR_2) until lce;
			f5 = PASS f9, f9 = dm(i3, m3), f3 = pm(i10, m8);
			f4 = f14 * f3, f10 = dm(i1, m6);	//f10=1/(w1-w0)
			f4 = f4 + f9,
			CCALL (_sinf);
			f8 = dm(_sin0);
			dm(_sin0) = f0;
			f7 = f0 - f8;				// f7=(sin1-sin0)

			f4 = f9 - f5;
			f4 = f4 * f10;
			f12 = f4 + f14;

			f4 = ABS f12;
			comp (f4, f13), f10 = dm(i2, m5);
			if LE jump (pc, calFIR_3), f4 = f1 * f14;
			call (pc, ___float_divide);
			jump (pc, calFIR_4);
calFIR_3:
			f4 = f4 + f5,
			CCALL (_cosf);
			f4 = f3 - f1;
			f7 = f4 * f0;
calFIR_4:
			f10 = f10 + f7;
calFIR_2:
			f1 = PASS f3, dm(i2, m5) = f10;

		f3 = PI;
		r6 = PASS r6;
		if EQ jump (pc, calFIR_5), f7 = f3 - f1;
		f4 = f3 * f14;
		f4 = f4 + f9,
		CCALL (_sinf);

		call (pc, ___float_divide)(DB);
		f8 = dm(_sin0);
		f7 = f0 - f8, f12 = f14;
		jump (pc, calFIR_6);
calFIR_5:
		f4 = f1 * f14;
		f4 = f4 + f5,
		CCALL (_cosf);
		f7 = f0 * f7;
calFIR_6:
		f10 = f10 + f7;
calFIR_1:
		r6 = r6 - 1, dm(i2, m6) = f10;

	f4  = 1.0/PI;
	i2  = i5;
	i10 = i2;
	f8  = dm(i2, m6);
	f6  = f8 * f4, f8 = dm(i2, m6);
	lcntr = FIR_N*2, do (pc, 1) until lce;
		f6 = f8 * f4, f8 = dm(i2, m6), pm(i10, m14) = f6;
	pm(i10, m14) = f6;
	rts;

_calculateFIR.end:


.global _smoothPhase;
/*
   convert phase range [-pi, +pi] to real (-\inf, +\inf)
   by adding or subtraction 2*pi period
   i2 -> HexPhaseData
   i10 -> predefinedPhase
   r0 = channel
 */
_smoothPhase:
	i2  = _HexPhaseData + 2;			// skip head
	r4  = _predefinedPhase;
	r8  = r4 + r0, r4 = dm(i2, m6);		// load first
	r5  = r5 - r5, i10 = r8;			// f5=nPI, i10=&_predefinedPhase[chn]
	f2  = 0.0001;
	r10 = r10 - r10, r8 = dm(i2, m6);	// last value, avoid breaking line
	f12 = 2.0*PI;
	m8  = 3;
	lcntr = N_OCTAVE, do(pc, validPhase) until lce;
		r8 = r8 OR FDEP r4 by 8:8(SE);
		f8 = FLOAT r8;
		f8 = f8 * f2, r4 = dm(i2, m6);
		f8 = f8 + f5;
		f6 = f8 - f10;
		COMP (f6, f11), f3 = f12;			// phase-phase0>2?
		if GT jump (pc, upRaise), else f6 = f6 + f11;
		if GT jump (pc, smooth), else f3 = -f12;
upRaise:
		f5 = f5 - f3;
		f8 = f8 - f3;
smooth:
validPhase:
		f10 = PASS f8, r8 = dm(i2, m6), pm(i10, m8) = f8;

	rts;
_smoothPhase.end:


.global _loadFromFlash;
/*
   load phase data from flash
   r0 = Channel No. (0=IN_A, 1=IN_B)
   r4 = Sector No.(with offset 21)
   return : ZF=OK, NE=invalid Flash data
 */
_loadFromFlash:
	i2  = _HexPhaseData;
	r8  = 2;
	CCALL (_readFlash);					// read head
	r2  = dm(_HexPhaseData + 0);
	r8  = dm(_HexPhaseData + 1);
	r8  = r8 OR FDEP r2 by 8:8;
	r6  = 0x55AA;						// signature
	COMP (r8, r6);
	if NE rts;							// NE=invalid

	i2  = _HexPhaseData;
	r8  = N_OCTAVE*2+2;
	CCALL (_readFlash);					// read all include head

	call (pc, _smoothPhase);

	rts, r6 = r6 - r6;					// EQ=valid
_loadFromFlash.end:

/* precalculate 1/(w_{i}-w_{i-1}), convert frequency Hz to radius */
_FreqPreset:
	i2  = _recipsFreq;
	i8  = _predefinedPhase + 2;
	m8  = 3;							// 2channels preset
	f14 = 2.0*PI/FS;
	r1  = r0 - r0;
	f2  = 1.0;
	lcntr = N_OCTAVE, do (pc, _freqpreset1) until lce;
		f3 = pm(i8, m13);
		call (pc, ___float_divide)(DB);
		f3 = f3 * f14, f7 = f2;
		f12 = f3 - f1, f1 = f3;
_freqpreset1:
		dm(i2, m6) = f7, pm(i8, m8) = f3;

	rts;
_FreqPreset.end:

.global _initPhase;
_initPhase:

	call (pc, _FreqPreset);

	call (pc, _loadFromFlash)(DB);
	r4  = 0;							// sector No.0
	r0  = 0;							// load as channel 0
	r4  = 0;							// channel 0
	call (pc, _calculateFIR);
	call (pc, _loadFromFlash)(DB);
	r4  = 1;							// sector No.1
	r0  = 1;							// load as channel 1
	r4  = 1;							// channel 1
	call (pc, _calculateFIR);

	f0  = 1.0;
	dm(_FIR_coeffs2 + FIR_N) = f0;
	dm(_FIR_coeffs3 + FIR_N) = f0;
	rts;
_initPhase.end:

