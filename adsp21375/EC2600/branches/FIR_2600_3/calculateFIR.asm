//////////////////////////////////////////////////////////////////////////////
//NAME:     calculateFIR.asm                                                //
//DATE:     2015-04-13                                                      //
//               Amplitude Focused                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.extern _sinf, _cosf, _exp_dB, ___float_divide;
.extern _readFlash, _windowFunction;

.section/dm seg_pmda;
.var _predefined[4*N_OCTAVE] =
#include "amplitude.h"
.var _linearAmp[N_OCTAVE+1];

.var _nsin0, _nsin1, _cos0, _cos1;

.global _HexData;
.var _HexData[N_OCTAVE*2+10];

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

	f1 = _omega0;
	f3 = _omega1;
	r5 = _Level0;
	r9 = _Level1;
 
	/  aw                1     aw
	| e   cos(nw)dw = ------- e  (n*sin(nw)+a*cos(nw))
	/                 a*a+n*n

        1
    ---------*[A1*(n*sin(n*w1)+k*c*cos(n*w1)-A0*(n*sin(n*w0)+k*c*cos(n*w0))]
     a*a+n*n
	A=10^(dB/20)=e^(c*dB), c=ln(10)/20=0.11512925464970229

	A=A(w)=exp(k*w+b);
	k*w+b = (dB1-dB0)/(w1-w0)*(w-w0)+dB0

 */

_linearAmplitude:
	i8  = _predefined;
	m8  = r4;
	modify(i8, m8);                     // predefined amplitude[chn]
	m8  = 4;
	i2  = _linearAmp+1;
	r6  = 181;
	r14 = PASS r4, r4 = pm(i8, m8);
	lcntr = N_OCTAVE, do (pc, linear1) until lce;
		r4 = r4 - r6;
		f4 = FLOAT r4,
		CCALL (_exp_dB);
linear1:
		dm(i2, m6) = f0, f4 = pm(i8, m8);

	rts(DB), r4 = PASS r14;
	f8 = dm(_linearAmp+1);
	dm(_linearAmp) = f8;

_linearAmplitude.end:

.global _calculateFIR;
/*
	r4 = channel (0, 1, 2, 3)
*/
_calculateFIR:

	call (pc, _linearAmplitude);

	i8  = _predefined;
	m8  = r4;
	modify(i8, m8);                     // predefined amplitude[chn]
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

	m3  = 4;							// 4 channels preset

	r6  = FIR_N;						// r6=FIR_N:-1:1 in loop
	f13 = 1.0277908852238316;			// frequency octave
	i2  = i5;							// i2->coeffs
	lcntr = r6, do (pc, calFIR_1) until lce;
		i3 = i8;						// i8->amplitude(dB)
		i10 = _linearAmp;
		dm(_nsin0) = m5;
		f0 = 1.0;
		dm(_cos0) = f0;
		f1 = 0.0;						// f1=omega0,f3=omega1;
		f3 = 20.0*2/FS*PI;
		f14 = FLOAT r6, r9 = dm(i3, m5);	// r5=Level0,f9=Level1;
		lcntr = N_OCTAVE, do (pc, calFIR_2) until lce;
			r5 = PASS r9, r9 = dm(i3, m3);
			r7 = r9 - r5;
			call (pc, ___float_divide)(DB);
			f7 = FLOAT r7;
			f12 = f3 - f1;

			f4 = 2.302585092994046/40;	// Amplitude step in 0.5dB
			f7 = f7 * f4;				// f7=c*k;

			f4 = f3 * f14, CCALL (_sinf);
			f10 = f14 * f0;
			dm(_nsin1) = f10;			// n*sin(n*w)

			f4 = f3 * f14, CCALL (_cosf);
			dm(_cos1) = f0;				// cos(n*w)

			f2 = dm(_nsin0);			// f2 =nsin0
			dm(_nsin0) = f10;			// f10=nsin1
			f4 = dm(_cos0);				// f4 =cos0
			dm(_cos0) = f0;				// f0 =cos1

			f4 = f7 * f4;				// k*c*cos(n*w0)
			f4 = f2 + f4,				// f4=(n*sin(n*w0)+k*c*cos(n*w0))
			f2 = pm(i10, m14);			// amp0
			f4 = f2 * f4;

			f0 = f7 * f0;				// k*c*cos(n*w1)
			f0 = f10 + f0,				// f0=(n*sin(n*w1)+k*c*cos(n*w1))
			f8 = pm(i10, m13);			// amp1
			f0 = f8 * f0;

			f12 = f7 * f7;
			f8 = f14 * f14, f2 = dm(i2, m5);
			
			call (pc, ___float_divide)(DB);
			f7 = f0 - f4;				// amp1*()-amp0*()
			f12 = f12 + f8;				// k*c*k*c+n*n

			f2 = f2 + f7, f1 = f3;
calFIR_2:
			f3 = f3 * f13, dm(i2, m5) = f2;

		f7 = pm(i10, m13);				// omega1=PI
		f4 = dm(_nsin1);
		call (pc, ___float_divide)(DB);
		f7 = f7 * f4;
		f12 = f14 * f14;

		f2 = f2 - f7;
calFIR_1:
		r6 = r6 - 1, dm(i2, m6) = f2;
	
	/******************* n=0 *******************/
	/*   c*((dB1-dB0)/(w1-w0)*(w-w0)+dB0)      */
    /* e                                       */
	/* = exp(c*k+b)                            */
	/*                                         */
	/* k==0:  A0*(w1-w0)                       */
	/* k!=0:  (A1-A0)/k                        */
	/*                                         */
	/*******************************************/

	i3  = i8;
	i10 = _linearAmp;
	r9  = dm(i3, m5);					// r5=Level0,f9=Level1;
	f1  = 0.0;							// f1=omega0,f3=omega1;
	f3  = 20.0*2/FS*PI;
	f14 = 1.0E-09;
	f4 = 2.302585092994046/40;			// Amplitude step in 0.5dB
	lcntr = N_OCTAVE, do(pc, calFIR_3) until lce;
		r5 = PASS r9, r9 = dm(i3, m3);
		r7 = r9 - r5;
		call (pc, ___float_divide)(DB);
		f7 = FLOAT r7;
		f12 = f3 - f1;

		f12 = f7 * f4;					// f12=c*k;

		f10 = pm(i10, m14);
		f6 = pm(i10, m13);

		f2 = ABS f12;
		comp (f2, f14), f2 = dm(i2, m5);
   		if GE jump (pc, calFIR_4), f7 = f6 - f10;
		f8 = f3 - f1;
		jump(pc, calFIR_5), f7 = f8 * f10;
calFIR_4:
		call (pc, ___float_divide);
calFIR_5:
		f2 = f2 + f7, f1 = f3;
calFIR_3:
		f3 = f3 * f13, dm(i2, m5) = f2;

	f3 = PI;
	f8 = f3 - f1;
	f7 = f8 * f6;
	f2 = f2 + f7;
	dm(i2, m5) = f2;
	/************************************************/
	/*            1                                 */
	/*  h(n) = ------ \int H(w)e^{jwn}dw            */
	/*          2*PI                                */
	/*                                              */
	/*     need *(1/PI) in windowfunction           */
	/*                                              */
	/************************************************/

	call (pc, _windowFunction);

	rts;

_calculateFIR.end:


.global _transferAmplitude;
/*
   convert HEX byte to unsigned int
   i2 -> HexData
   i10 -> predefined
   r0 = channel
 */
_transferAmplitude:
	i2  = _HexData + 2;					// skip head
	i10 = _predefined;
	m8  = r0;
	modify(i10, m8);
	r4 = dm(i2, m6);					// load first
	m8  = 4;							// 4 channels preset
	r6  = 0x200;
	r2  = FEXT r4 by r6, r4 = dm(i2, m6);
	lcntr = N_OCTAVE, do (pc, 1) until lce;
		r2 = FEXT r4 by r6, r4 = dm(i2, m6), pm(i10, m8) = r2;

	rts;
_transferAmplitude.end:


.global _loadFromFlash;
/*
   load phase data from flash
   r0 = Channel No. (0=IN_A, 1=IN_B)
   r4 = Sector No.(with offset 21)
   return : ZF=OK, NE=invalid Flash data
 */
_loadFromFlash:
	i2  = _HexData;
	r8  = 2;
	CCALL (_readFlash);					// read head
	r2  = dm(_HexData + 0);
	r8  = dm(_HexData + 1);
	r8  = r8 OR FDEP r2 by 8:8;
	r6  = 0x55AA;						// signature
	COMP (r8, r6);
	if NE rts;							// NE=invalid

	i2  = _HexData;
	r8  = N_OCTAVE*2+2;
	CCALL (_readFlash);					// read all include head

	call (pc, _transferAmplitude);
	rts, r6 = r6 - r6;					// EQ=valid
_loadFromFlash.end:

.global _initFIRs;
_initFIRs:
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
	call (pc, _loadFromFlash)(DB);
	r4  = 2;							// sector No.2
	r0  = 2;							// load as channel 2
	r4  = 2;							// channel 2
	call (pc, _calculateFIR);
	call (pc, _loadFromFlash)(DB);
	r4  = 3;							// sector No.3
	r0  = 3;							// load as channel 3
	r4  = 3;							// channel 3
	call (pc, _calculateFIR);

	rts;
_initFIRs.end:

