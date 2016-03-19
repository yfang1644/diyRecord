#include "constant.h"
#include "lib_glob.h"

// 输入参数均衡器预置 PEQParam: type, frequency[1,121], level, q=[0,72]
//	level = -12dB -- +12dB, step 0.5dB, 0x00 = 0dB
// type:
/*
	Function: caculating parameter equalizer's coeffs
	Import:	  Type,Freq,Level,Q in peqstruct
	type:
		0: Equalizer OFF
		1: Peaking Equalizer
		2: Bandpass filter
		3: High-Shelving Equalizer
		4: Low-Shelving Equalizer
		5: Notch Filter
		0x81 -- GEQ
	level = -12dB -- +12dB, step 0.5dB, 0x00 = 0dB
*/

.extern _pCoeff, _pGain, _index;

.extern _FrequencyTable;
.extern _QTable;
.extern ___float_divide, _sqrtf, _sinf, _cosf, _expf;

.section/dm seg_dmda;

.var peq_jump_table[] =
	defaultPEQ,
	Peaking,				// Level Q
	Bandpass,				// Q
	HighShelving,			// Level
	LowShelving,			// Level
	Notch;					// Q

.var freq, q;
.var A, sinw, cosw, alpha, beta;
.var _b0, _b1, _b2, _a0, _a1, _a2;

.section/pm seg_pmco1;
.global _calculatePEQ;
_calculatePEQ:

	i11 = dm(_pGain);
	m12 = dm(_index);
	f12 = 1.0;
	r0 = r0 - r0, pm(m12, i11) = f12;	// preset gain = 1;

	r1 = m12;
	r1 = lshift r1 by 2;
	r12 = dm(_pCoeff);
	r12 = r12 + r1;
	i8 = r12;
	pm(0, i8) = f0;
	pm(1, i8) = f0;
	pm(2, i8) = f0;
	pm(3, i8) = f0;						// a1,a2,b1,b2 = 0 as no filter

	r5 = FEXT r4 by 24:8;				// PEQ type(not changed in sin,exp)

	r2 = FEXT r4 by 16:8;				// valid frequency index [1 ~121]
	if SZ jump (pc, defaultPEQ);		// freq=(1-121)
	r1 = 121;
	comp (r2, r1);
	if GT jump (pc, defaultPEQ);
	dm(freq) = r2;

	r2 = FEXT r4 by 8:8;				// level(000~048, -12dB~+12dB)
	r3 = 24;
	r2 = r2 - r3, puts = r4;
	f2 = FLOAT r2;
	f1 = 2.30258509299404590109/80.0;	// ln(10.0)/80, 0.5dB/step
	f4 = f1 * f2;						// only for Peaking and Shelv
	CCALL (_expf);
	dm(A) = f0;
	f4 = f0 + f0, r6 = gets(1);			// for Peaking&Shelving EQ only
	CCALL (_sqrtf);						// r6 not used in sqrt
	dm(beta) = f0;						// beta = sqrt[ (A^2 + 1)/S - (A-1)^2 ]
										// for shelf type only
										// S(shelf slope)=1 for this application

	r3 = FEXT r6 by 0:8;				// Q value index
	f3 = FLOAT r3, alter(m6);			// replace alter(1)
	f4 = 20.5;
	f1 = 2.30258509299404590109/40.0;
	f3 = f3 - f4;
	f4 = f1 * f3;
	CCALL (_expf);						// Q=exp(i)
	dm(alpha) = f0;						// Q: [0 ~ 72]

	r2 = dm(freq);
	f2 = float r2;
	f1 = 0.0577622650466621;			// ln(2)/12
	f4 = f1 * f2;
	CCALL (_expf);
	f2 = 2.0 * 18.65 * PI / FS;			// freq=18.9*10^(i/12),20Hz(i=1),1k(i=69)
	f4 = f0 * f2;						// 2*omega =2*PI*f/FS

	f6 = f4;
	CCALL (_cosf);
	dm(cosw) = f0;
	f4 = f6;
	CCALL (_sinf);
	dm(sinw) = f0;

	call (pc, ___float_divide)(DB);
	f12 = dm(alpha);
	f12 = f12 + f12, f7 = f0;

	f2 = 1.0;							// often used
	f12 = dm(A);nop;
	f3 = dm(beta);nop;

	r1 = @peq_jump_table;
	comp(r5, r1);						// r5 holds PEQ type
	if GE r5 = r5 - r5;
	i4 = peq_jump_table;
	m4 = r5;
	i13 = dm(m4, i4);
	jump (m13, i13)(DB);				// m13 = 0
	f5 = dm(sinw);
	f6 = dm(cosw);
Peaking:
	f4 = f12 * f7;
	f6 = f6 + f6;
	f0 = f2 + f4, f8 = f2 - f4;
	dm(_b0) = f0;						// b0 = 1 + alpha * A;
	dm(_b2) = f8;						// b2 = 1 - alpha * A;
	dm(_a1) = f6;						// -a1 = 2*cosw;
	f6 = -f6;
	dm(_b1) = f6;						// b1 = -2*cosw;
	call ___float_divide;
	f4 = f7 + f2, f0 = f7 - f2;
	dm(_a0) = f4;						// a0 = 1 + alpha / A;
	dm(_a2) = f0;						// -a2 = alpha / A - 1;
	jump setparm;
Bandpass:
	dm(_b0) = f7;						// b0 = alpha;
	dm(_b1) = m5;						// b1 = 0;
	f4 = f7 + f2, f0 = f7 - f2;
	dm(_a0) = f4;						// a0 = 1 + alpha;
	dm(_a2) = f0;						// -a2 = alpha-1;
	f5 = f6 + f6;
	dm(_a1) = f5;						// -a1 = 2 * cosw;
	f7 = -f7;
	dm(_b2) = f7;						// b2 = -alpha;
	jump setparm;
HighShelving:
	jump (pc, 4)(DB);
	f6 = -f6;							// cosw = -cosw
	f10 = -2.0;							// 2*xxx -> -2*xxx
LowShelving:
	f10 = 2.0;							// 2*xxx
	f9 = f12 + f2, f7 = f12 - f2;		// f7=A-1, f9=A+1
	f13 = f6 * f7;						// f13=(A-1)*cosw
	f8 = f3 * f5, f1 = f9 - f13;		// f8=beta*sinw,f1=(A+1)-(A-1)*cosw
	f0 = f1 + f8, f4 = f1 - f8;
	f0 = f12 * f0;
	f4 = f12 * f4;
	dm(_b0) = f0;						// b0=A*((A+1)-(A-1)*cosw + beta*sinw);
	dm(_b2) = f4;						// b2=A*((A+1)-(A-1)*cosw - beta*sinw);
	f1 = f9 + f13;
	f0 = f8 + f1, f4 = f8 - f1;
	dm(_a0) = f0;						// a0=(A+1)+(A-1)*cosw + beta*sinw;
	dm(_a2) = f4;						// -a2=-((A+1)+(A-1)*cosw - beta*sinw);
	f13 = f6 * f9;						// f13=(A+1)*cosw
	f0 = f7 + f13, f1 = f7 - f13;
	f0 = f10 * f0;
	f1 = f10 * f1;
	f1 = f1 * f12;
	dm(_a1) = f0;						// -a1=2*((A-1)+(A+1)*cosw);
	dm(_b1) = f1;						// b1 = 2*A*((A-1) - (A+1)*cosw);
	jump setparm;
Notch:
	dm(_b0) = f2;						// b0 = 1;
	dm(_b2) = f2;						// b2 = 1;
	f0 = f7 + f2, f1 = f7 - f2;
	dm(_a0) = f0;						// a0 = 1+alpha
	dm(_a2) = f1;						// -a2 = alpha-1
	f6 = f6 + f6;						// f10 = 2*cosw
	dm(_a1) = f6;						// -a1 = 2*cosw
	f6 = -f6;
	dm(_b1) = f6;						// b1 = -2*cosw
	jump setparm;

setparm:
	call (pc, ___float_divide)(DB);
	f7 = 1.0;
	f12 = dm(_a0);
	f12 = dm(_b0);
	f0 = f12 * f7;
	f4 = dm(_a2);
	f4 = f4 * f7, pm(m12, i11) = f0;	// restore gain
	f0 = dm(_a1);
	f4 = f0 * f7, pm(i8, m14) = f4;	// restore -a2
	call (pc, ___float_divide)(DB);
	f7 = 1.0;
	f8 = dm(_b1);
	f0 = dm(_b2);
	f0 = f0 * f7, pm(i8, m14) = f4;	// restore -a1
	f4 = f8 * f7, pm(i8, m14) = f0;	// restore b2
	pm(i8, m14) = f4;					// restore b1
defaultPEQ:
	EXIT;
_calculatePEQ.end:

