////////////////////////////////////////////////////////////////////////////
//                                                                        //
// Window Functions                                                       //
//                                                                        //
////////////////////////////////////////////////////////////////////////////

#include <def21375.h>

#include "lib_glob.h"
#include "constant.h"

.extern _sinf, _cosf, ___float_divide;

.section/dm seg_dmda;
.global _winF;
.var _winF = 3;

.var _windowList[] =
	rectangle,				// -21.7dB, 4*pi/N
	bartlett,				// -25dB,  8*pi/N
	hanning,				// -31dB,  8*pi/N
	hamming,				// -41dB,  8*pi/N
	blackman,				// -57dB,  12*pi/N
	kaiser;

.section/pm	seg_pmco;

.global _windowFunction;
_windowFunction:
	r5  = dm(_winF);
	r1  = @_windowList;
	comp (r5, r1), r1 = m6;
	if GE rts;							// invalid, return

	i4 = _windowList;
	m4 = r5;
	i13 = dm(m4, i4);
	jump (m13, i13);

_windowFunction.end:

rectangle:
	f7  = 1.0/PI;
	i2  = i5;
	i8  = i5;
	i10 = i5;
	modify(i10, 2*FIR_N);
	f9  = dm(i2, m6);
	f0 = f9 * f7, f9 = dm(i2, m6);
	lcntr = FIR_N, do (pc, 2) until lce;
		pm(i10, m15) = f0;
		f0 = f9 * f7, f9 = dm(i2, m6), pm(i8, m14) = f0;

	pm(i8, m14) = f0;

	rts;
rectangle.end:

/*  triangle window */
bartlett:
	call (pc, ___float_divide)(DB);
	f7  = 1.0/PI;
	f12 = 1.0*FIR_N;
	i2  = i5;
	i8  = i5;
	i10 = i5;
	modify(i10, 2*FIR_N);
	r10 = r10 - r10, f9  = dm(i2, m6);
	lcntr = FIR_N+1, do (pc, 3) until lce;
		f0 = f10 * f9;
		pm(i10, m15) = f0;
		f10 = f10 + f7, f9 = dm(i2, m6), pm(i8, m14) = f0;

	rts;
bartlett.end:

/*  w(n) = 0.5*[1-cos(2*pi*n/(N-1)] = sin^2(pi*n/(N-1)) */
hanning:
	call (pc, ___float_divide)(DB);
	f7  = PI;
	f12 = 2.0*FIR_N;
	i2  = i5;
	i8  = i5;
	i10 = i5;
	modify(i10, 2*FIR_N);
	r10 = r10 - r10, f9 = dm(i2, m6);
	f3  = 1.0/PI;
	lcntr = FIR_N+1, do (pc, hanning1) until lce;
		f4 = PASS f10, CCALL (_sinf);
		f0 = f0 * f0;
		f0 = f0 * f3;
		f0 = f0 * f9;
		pm(i10, m15) = f0;
hanning1:
		f10 = f10 + f7, f9 = dm(i2, m6), pm(i8, m14) = f0;

	rts;
hanning.end:

/*  w(n) = 0.54-0.46*cos(2*pi*n/(N-1))
	     = 0.08+0.92*sin^2(pi*n/(N-1))
 */
hamming:
	call (pc, ___float_divide)(DB);
	f7  = PI;
	f12 = 2.0*FIR_N;
	i2  = i5;
	i8  = i5;
	i10 = i5;
	modify(i10, 2*FIR_N);
	r10 = r10 - r10, f9 = dm(i2, m6);
	f1 = 0.08/PI;
	f3 = 0.92/PI;
	lcntr = FIR_N+1, do (pc, hamming1) until lce;
		f4 = PASS f10, CCALL (_sinf);
		f0 = f0 * f0;
		f0 = f3 * f0;
		f0 = f1 + f0;
		f0 = f0 * f9;
		pm(i10, m15) = f0;
hamming1:
		f10 = f10 + f7, f9 = dm(i2, m6), pm(i8, m14) = f0;

	rts;
hamming.end:

/*  w(n) = 0.42-0.5*cos(2*pi*n/(N-1))+0.08*cos(4*pi*n/(N-1))
	     = sin^2(pi*n/(N-1))*(0.36+0.64*sin^2(pi*n/(N-1)))
 */
blackman:
	call (pc, ___float_divide)(DB);
	f7  = PI;
	f12 = 2.0*FIR_N;
	i2  = i5;
	i8  = i5;
	i10 = i5;
	modify(i10, 2*FIR_N);
	r10 = r10 - r10, f9 = dm(i2, m6);
	f1 = 0.36/PI;
	f3 = 0.64/PI;
	lcntr = FIR_N, do (pc, blackman1) until lce;
		f4 = PASS f10, CCALL (_sinf);
		f0 = f0 * f0;
		f4 = f0 * f3;
		f4 = f4 + f1;
		f0 = f4 * f0;
		f0 = f0 * f9;
		pm(i10, m15) = f0;
blackman1:
		f10 = f10 + f7, f9 = dm(i2, m6), pm(i10, m15) = f0;

	rts;
blackman.end:

kaiser:
	rts;
kaiser.end:


