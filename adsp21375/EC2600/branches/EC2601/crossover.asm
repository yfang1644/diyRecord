#include "constant.h"
#include "lib_glob.h"

// 输入参数均衡器预置 PEQParam: type[0-11], frequency[1,121], level, q=[0,72]
//	level = -12dB -- +12dB, step 0.5dB, 0x00 = 0dB
// type:
//	when frequency=0, let type=0:Equalizer OFF
/*
	Function: Calculate HPF/LPF coefficients, max. 6th order
	Import:	  type,Freq,type, freq in peqstruct
	type:
		0: direct
		1: Butterworth, 2nd order(-12dB/oct)
		2: Butterworth, 3rd order(-18dB/oct)
		3: Butterworth, 4th order(-24dB/oct)
		4: Butterworth, 5th order(-30dB/oct)
		5: Butterworth, 6th order(-36dB/oct)
		6: Bessel, 2nd order
		7: Bessel, 3nd order
		8: Bessel, 4th order
		9: Bessel, 5th order
		10:Bessel, 6th order
		11:Linkwitz-Riley, 2nd order
		12:Linkwitz-Riley, 4th order

*/

.extern ___float_divide, _tanf, _expf;

.section/dm seg_dmda;
.global _pCoeff, _pGain, _index, _low_pass;
.var _pCoeff, _pGain, _index;
.var _low_pass;
.var wc;

.var crossover_jump_table[] =
	Butterworth2,
	Butterworth3,
	Butterworth4,
	Butterworth5,
	Butterworth6,
	Bessel2,
	Bessel3,
	Bessel4,
	Bessel5,
	Bessel6,
	LinkwitzRiley2,
	LinkwitzRiley4;

.section/pm seg_pmco1;

_iirFirstOrder:							// f7=wo
	f12 = dm(wc);
	r0 = dm(_low_pass);
	f2 = float r0;						// f2 = (float)low_pass
	if GT jump (pc, 2), f7 = f7 * f12;	// f7 = rk=wo*wc
	call (pc, ___float_divide);			// f7 = rk=wo/wc

	call (pc, ___float_divide)(DB);
	f7 = ABS f2, f3 = f7;				// f7 = 1, f3=rk
	f12 = f3 + f7;

	f6 = f3 * f7, f0 = m5;
	f3 = f7 - f6, pm(i8, m14) = f0;		// -a2 = 0
	f1 = f2 * f3, pm(i11, m14) = f6;	// gain =rk*temp
	f1 = abs f2, pm(i8, m14) = f1;		// -a1 = low_pass*(temp-rk*temp)
										// f0 = 0, f1 = 1 for later use
	pm(i8, m14) = f0;					// b2 = 0
	pm(i8, m14) = f2;					// b1 = low_pass
	rts;
_iirFirstOrder.end:

_iirSecondOrder:						// f7=wo,f10=pk
	f12 = dm(wc);
	r0 = dm(_low_pass);
	f2 = float r0;						// f2 = (float)low_pass
	if GT jump (pc, 2), f7 = f7 * f12;	// f7=rk=wo*wc
	call (pc, ___float_divide);			// f7=rk=wo/wc

	f8 = f7 * f7, f9 = f2;				// f8=rk^2, f9,f13 used later
	f10 = f10 * f7, f13 = f2;			// f10=pk*rk
	f7 = abs f2;						// f7=1
	call (pc, ___float_divide)(DB);
	f14 = f7 + f8, f6 = f7 - f8;		// f14=1+rk^2,f6=1-rk^2
	f12 = f10 + f14, f3 = f10 - f14;	// f12=pr+r^2+1,f3=pr-r^2-1

	f0 = f8 * f7;						// f0=g
	f4 = f3 * f7, f3 = f9 + f13, pm(i11, m14)= f0;
	// f4=-a2, f3=2*low_pass, restore gain
	f12 = f6 * f7, pm(i8, m14) = f4;	// -a2
	f7 = f12 * f3;
	f1 = abs f2, pm(i8, m14) = f7;		// -a1
	r0 = r0 - r0, pm(i8, m14) = f1;		// b2=1
	pm(i8, m14) = f3;					// b1=+2 or -2
	rts;
_iirSecondOrder.end:


.global _calculateCrossover;
_calculateCrossover:
// only LSB 16 of r4 valid
// low_pass = 1 for low pass filter, -1 for high pass filter

	r1 = dm(_pGain);
	r2 = dm(_index);
	r1 = r1 + r2;
	i11 = r1;							// gain[index]

	r1 = LSHIFT r2 by 2;
	r12 = dm(_pCoeff);
	r12 = r12 + r1;
	i8 = r12;							// coeff[4*index]

	r5 = FEXT r4 by 8:8;				// type in R5(not used in tanf, expf)

	f1 = 1.0;
	r2 = FEXT r4 by 0:8;				// Freq: [1 ~ 121]
	if SZ jump (pc, defaultCrossover), r0 = r0 - r0;
	r0 = 121;
	comp (r2, r0);
	if GT jump (pc, defaultCrossover), r0 = r0 - r0;

	f2 = float r2;
	f1 = 0.0577622650466621;			// ln(2)/12
	f4 = f1 * f2,
	CCALL (_expf);
	f2 = 18.65 * PI / FS;				// freq=20*10^(i/12)
	f4 = f0 * f2,						// omega=2*PI*freq/FS
	CCALL (_tanf);
	dm(wc) = f0;						// wc = tan(PI*freq/FS)	

	r1 = @crossover_jump_table;
	comp(r5, r1), r1 = m6;
	if GE jump (pc, crossover_End);		// invalid, do nothing
	i4 = crossover_jump_table;
	m4 = r5;
	f1 = FLOAT r1, i13 = dm(m4, i4);
	jump (m13, i13), r0 = r0 - r0;		// m13 = 0

defaultCrossover:
	pm(i11, m14) = f1;
	lcntr = 4, do (pc, 1) until lce;
		pm(i8, m14) = f0;
iir_stage2:
	pm(i11, m14) = f1;
	lcntr = 4, do (pc, 1) until lce;
		pm(i8, m14) = f0;
iir_stage3:
	pm(i11, m14) = f1;
	lcntr = 4, do (pc, 1) until lce;
		pm(i8, m14) = f0;
crossover_End:
	EXIT;

Butterworth2:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.414213562373095;			// 2 * sin(PI/4);
	jump iir_stage2;

Butterworth3:
	call (pc, _iirFirstOrder)(DB);
	f7 = 1.0;
	nop;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.0;							// 2 * sin(PI/6);
	jump iir_stage3;

Butterworth4:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 0.76536686473018;				// 2 * sin(PI/8);

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.84775906502257351;			// 2 * sin(3*PI/8);
	jump iir_stage3;

Butterworth5:
	call (pc, _iirFirstOrder)(DB);
	f7 = 1.0;
	nop;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 0.6180339887498948482;		// 2 * sin(PI/10);

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.6180339887498948482;		// 2 * sin(3*PI/10);
	jump crossover_End;

Butterworth6:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 0.517638090205;				// 2 * sin(PI/12);

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.414213562373095;			// 2 * sin(3*PI/12);

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.9318516525781365735;		// 2 * sin(5*PI/12);
	jump crossover_End;

Bessel2:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.272019649514069;
	f10 = 1.732050807568877;			// 3/sqrt(3)
	jump iir_stage2;

Bessel3:
	call (pc, _iirFirstOrder)(DB);
	f7 = 1.322675799895588;
	nop;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.447617133148852;
	f10 = 1.447080359898814;
	jump iir_stage3;

Bessel4:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.603357516232937;
	f10 = 1.241405930098654;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.430171559972244;
	f10 = 1.915948923733869;
	jump iir_stage3;

Bessel5:
	call (pc, _iirFirstOrder)(DB);
	f7 = 1.502316271435266;
	nop;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.755377776624902;
	f10 = 1.091134411433174;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.556347122314373;
	f10 = 1.774510719467443;
	jump crossover_End;

Bessel6:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.904707612314687;
	f10 = 0.9772172032345484;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.689168267600359;
	f10 = 1.636140252089971;

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.603919128779323;
	f10 = 1.959563141846909;
	jump crossover_End;

LinkwitzRiley2:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 2.0;
	jump iir_stage2;

LinkwitzRiley4:
	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.414213562373095;			//2*sin(PI/4)

	call (pc, _iirSecondOrder)(DB);
	f7 = 1.0;
	f10 = 1.414213562373095;			//2*sin(PI/4)
	jump iir_stage3;

_calculateCrossover.end:

