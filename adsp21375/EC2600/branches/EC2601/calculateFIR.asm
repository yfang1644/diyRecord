//////////////////////////////////////////////////////////////////////////////
//NAME:     calculateFIR.asm                                                //
//DATE:     2015-04-13                                                      //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.extern _sinf, _cosf, _atan2f;
.extern _inp_coeffs, _outp_coeffs;
.extern _pCoeff, _pGain, _FIR_coeffs0, _outputChannel;
.extern _index, _a0, _b0, sinw, cosw;
.global _calculateFIR;

.section/pm seg_pmco;

/*
	(1 + b1*cos + b2*(2*cos*cos-1)) - j(b1*sin + 2*b2*sin*cos)
		re = (1-b2) + cos*(b1 + 2*b2*cos)
		im = -sin*(b1 + 2*b2*cos)

	(1 - a1*cos - a2*(2*cos*cos-1)) + j(a1*sin + 2*a2*sin*cos)
		re = (1+a2) - cos*(a1 + 2*a2*cos)
		im = sin*(a1 + 2*a2*cos)

	f3=cos, f0=sin
	complex A(f1, f6)
	complex B(f7, f13)
 */
_multiBiquad:
	f8 = dm(i2, m6);					// f8=a2
	lcntr = r4, do (pc, multiBiquad1) until lce;
		f4  = f8 + f8, f2 = dm(i2, m6);	// f4=2*a2, f2=a1
		f4  = f4 * f3, f8 = f8 + f12;	// f4=2*a2*cos, f8=(a2+1)
		f4  = f2 + f4;					// f4=a1+2*a2*cos
		f14 = f3 * f4;					// f14=cos*(a1+2*a2*cos)
		f5  = f0 * f4, f9 = f8 - f14;	// f5=IMAG, f9=REAL

		f8  = f1 * f9;					// f8=R1*R2
		f14 = f6 * f5;					// f14=I1*I2
		f4  = f6 * f9;					// f4=I1*R2
		f5  = f1 * f5, f1 = f8 - f14;	// f5=R1*I2, f0=REAL

		f6  = f4 + f5, f8 = dm(i2, m6);	// f6=IMAG, f8=b2
		f4  = f8 + f8, f2 = dm(i2, m6);	// f4=2*b2, f2=b1
		f4  = f4 * f3, f14 = f8 - f12;	// f4=2*b2*cos, f14=(b2-1)
		f4  = f2 + f4;					// f4=b1+2*b2*cos
		f8  = f3 * f4;					// f8=cos*(b1+2*b2*cos)
		f2  = f0 * f4, f9 = f8 - f14;	// f2=-IMAG,f9=REAL

		f14 = f7 * f9;					// f14=R1*R2
		f8  = f13 * f2;					// f8=I1*(-I2)
		f4  = f13 * f9;					// f4=I1*R2
		f5  = f2 * f7, f7 = f8 + f14;	// f5=(-I2)*R1, f7=REAL
multiBiquad1:
		f13 = f4 - f5, f8 = dm(i2, m6);	// f13=IMAG,f8=a2

	EXIT;

_multiBiquad.end:


_IIR_response:
	f6 = PASS f4,
	CCALL (_cosf);				// f3, f6 not used in _cosf
	f4 = PASS f6, f3 = f0;
	CCALL (_sinf);				// f0=sin, f3=cos
	dm(sinw) = f0;
	dm(cosw) = f3;

	f12 = 1.0;
	r6 = r6 - r6, r1 = r12;			// complex A(f1, f6)
	r13 = r13 - r13, r7 = r12;		// complex B(f7, f13)

	i2 = dm(_index);
	r4 = 11;
	CCALL (_multiBiquad);
	i2 = dm(_pGain);
	r4 = 9;
	CCALL (_multiBiquad);

	f10 = f1 * f13;					// (f7+jf13)*(f1-jf6)
	f12 = f6 * f7;
	f8  = f1 * f7, f4 = f10 - f12;
	f2  = f6 * f13;
	f8  = f8 + f2,
	CCALL (_atan2f);				// f0 = atan(f4/f8);
		
	EXIT;
_IIR_response.end:


_calculateFIR:
	r2  = dm(_pCoeff);
	r6  = 2*FIR_N + 1;
	r8  = _FIR_coeffs0;
	r4  = r2 * r6(UUI);
	r4  = r4 + r8;
	dm(_pCoeff) = r4;					// _pCoeff = _FIR_coeffs0+N*(2*FIR_N+1)

	r4  = 4*OUT_PEQS;
	r8  = _outp_coeffs;
	r4  = r2 * r4(UUI);
	r4  = r4 + r8;
	dm(_pGain) = r4;					// _pGain = _outp_coeffs+N*4*OUT_PEQS

	r4  = 26;
	r10 = _outputChannel + 1;
	r4  = r2 * r4;
	r4  = r4 + r10;
	i2  = r4;
	r6  = dm(i2, m5);					// _outputChannelxN+1
	r4  = 4*IN_PEQS;
	r6  = r6 - 1;
	if LE r4 = r4 - r4;					// channel 1; else channel 2
	r6  = _inp_coeffs;
	r6  = r6 + r4;
	dm(_index) = r6;					// _index=_inp_coeffs+M*4*IN_PEQS

	i2  = dm(_pCoeff);
	lcntr = FIR_N*2+1, do (pc, 1) until lce;	// FIR_coeffs={0}
		dm(i2, m6) = m13;

	dm(_a0) = m5;						// nPI
	dm(_b0) = m5;						// phase0
	f4 = 2.0*PI/FS;
	r0 = r0 - r0, puts = f4;
	puts = r0;
	lcntr = 32226, do (pc, calFIR_1) until lce;
		f8 = FLOAT r0, f4 = gets(2);
		f4 = f4 * f8,
		CCALL (_IIR_response);

		f8 = dm(_a0);					// nPI
		f0 = f0 + f8;
		f2 = dm(_b0);					// phase0
		f4 = f0 - f2, r5 = gets(1);		// r5=LOOP counter
		comp(f4, f11);					// phase-phase0>2
		if LE JUMP(pc, calFIR_3);
		f6 = PI;
		f8 = f8 - f6;
		dm(_a0) = f8;
		f0 = f0 - f6;
calFIR_3:
		dm(_b0) = f0;					// monotune phase

		f8 = FLOAT r5, f4 = gets(2);	// r5=LOOP counter,f4=PI/30000.0
		f2 = -1.0;						// phi = k*omega
		f4 = f4 * f8;					// f4=arg
		f8 = f2 * f4;					// f8=phi=-1.0*omega
		f10 = f8 - f0;					// phase
		i2 = dm(_pCoeff);
		f6 = -FIR_N*1.0;				// f6=i
//		fir_coeffs[taps] += 2 * mag * cos(pha + arg*(taps-FIR_N)) * dOmega;
//		  cos(pha - arg*FIR_N + arg*taps)
//		= cos(phX)*cosX - sin(phX)*sinX
//		  sin(phX+arg)
//		= sin(phX)*cosX + cos(phX)*sinX
		f4 = f4 * f6;
		f4 = f4 + f10;
		f6 = PASS f4,
		CCALL (_cosf);
		f4 = PASS f6, f14 = f0;
		CCALL (_sinf);					// f14=cos(phX),f0=sin(phX)

		f4 = dm(cosw);					// f4=cosX,     f6=sinX
		f6 = dm(sinw);
		lcntr = 2*FIR_N+1, do (pc, calFIR_2) until lce;
			f9  = f14 * f4, f8 = dm(i2, m5);	// f9=cosx*cosy
			f12 = f0 * f6, f8 = f8 + f14;		// f12=sinx*siny, f8+=cos(phY)
			f2  = f6 * f14, dm(i2, m6) = f8;	// f2=cosx*siny, restore fir[]
			f3  = f0 * f4, f14 = f9 - f12;		// f3=sinx*cosy, f14=new cos(phY)
calFIR_2:
			f0  = f2 + f3;

		r0 = r5 + 1;
calFIR_1:
		dm(m6, i7) = r0;

	alter(2);

	f4 = 2.0/FS;
	i2 = dm(_pCoeff);
	i10 = i2;
	f8 = dm(i2, m6);
	f6 = f8 * f4, f8 = dm(i2, m6);
	lcntr = FIR_N*2+1, do (pc, 1) until lce;
		f6 = f8 * f4, f8 = dm(i2, m6), pm(i10, m14) = f6;

	rts;
_calculateFIR.end:

