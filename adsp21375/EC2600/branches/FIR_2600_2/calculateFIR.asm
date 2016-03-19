//////////////////////////////////////////////////////////////////////////////
//NAME:     calculateFIR.asm                                                //
//DATE:     2015-04-13                                                      //
//              PHASE FOCUSED                                               //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.extern _sinf, _cosf, ___float_divide;
.extern _readFlash;

.section/dm seg_pmda;
.var _predefinedPhase[INS*N_OCTAVE] =
#include "initialphase.h"

.var _preWrap[CUTLINE] =	// lowpass phase(crossover+resampling)
#include "prewrap.h"

.global _HexPhaseData;
.var _HexPhaseData[N_OCTAVE*2+2];
.global _FIR_coeffs0;
.global _crossHPF, _crossLPF, _smoothLPF;

.var _FIR_coeffs0[2*FIR_L+1 + 2*FIR_H+1];	// channel 0
.var _FIR_coeffs1[2*FIR_L+1 + 2*FIR_H+1];	// channel 1
.var _FIR_coeffs2[2*FIR_L+1 + 2*FIR_H+1];
.var _FIR_coeffs3[2*FIR_L+1 + 2*FIR_H+1];
/*
CROSSN = 181; xset('window', 1);
hnc1 = eqfir(CROSSN, [0 0.02; 0.0398 0.499],[1.0 0.0001],[0.1 0.9]);
[hm1, fr] = frmag(hnc1, 2048); clf; plot(fr, 20*log10(hm1),'r')
hnc2 = eqfir(CROSSN, [0 0.0175; 0.038 0.499],[0.0001 1.0],[0.9 0.1]);
[hm2, fr] = frmag(hnc2, 2048); plot(fr, 20*log10(hm2))

clf;plot(fr,hm1+hm2);
*/
.var _crossHPF[CROSSN] =	// crossover highpass(FIR)
#include "hpf.h"

.var _crossLPF[] =		// 8th order butterworth lowpass, for crossover cutoff
//#include "lpf.h"
	-0.935881972313, 1.907779574394, 1.0, 2.0,
	-0.827618837357, 1.801088094711, 1.0, 2.0,
	-0.752602636814, 1.727160930634, 1.0, 2.0,
	-0.714516580105, 1.689627766609, 1.0, 2.0,
	0.007025597151*0.006632694509*0.006360449828*0.006222229917;

.var _smoothLPF[] = 	// 10th order butterworth lowpass, for resampling
	-0.938356995583, 1.897881150246, 1.0, 2.0,
	-0.831012189388, 1.792777895927, 1.0, 2.0,
	-0.748636603355, 1.712122321129, 1.0, 2.0,
	-0.693288981915, 1.657930493355, 1.0, 2.0,
	-0.665573179722, 1.630793452263, 1.0, 2.0,
	0.010118983686*0.009558601305*0.009128568694*0.008839632384*0.008694944903;

.section/pm seg_pmco;

.global _calculateFIR;
/*
	r4 = channel (0, 1)
*/
_calculateFIR:
	i3  = _predefinedPhase;
	m3  = r4;
	modify(i3, m3);						// predefinedPhase[chn]
	r8  = @_FIR_coeffs0;
	r6  = r4 * r8 (UUI);
	i5  = _FIR_coeffs0;
	m3  = r6;
	modify(i5, m3);						// _FIR_coeffs[]

	i2  = i5;
	i10 = i2;
	r0  = r0 - r0, modify(i10, m14);
	lcntr = FIR_L+FIR_H+1, do (pc, 1) until lce;
		dm(i2, m2) = r0, pm(i10, m10) = r0;		// m2=m10=2
	dm(i2, m2) = r0;				// clear 2*FIR_x+1

	m3  = 2;						// 2 channels preset
/************************** Low frequency range *****************/
	f14 = F_OCTAVE;
	f13 = 1.0E-05;					// sin(x)/x = 1 when |x| < f13
	f1  = 0.0;						// _omega0;
	f3  = 10.0*2*PI/(FS/16.0);		// _omega1;
	f9  = 0.0;						// _ph1;
// f1=_omega0, f5=_ph0,  f3=_omega1, f9=_ph1
	lcntr = CUTLINE, do (pc, calFIR_1) until lce;
		r6 = FIR_L;					// r6=-FIR_N:FIR_N in loop
		call (pc, _accumulateFIR)(DB);
		f5 = PASS f9, f9 = dm(i3, m3); 
		i2 = i5;
calFIR_1:
		f3 = f3 * f14, f1 = f3;

	r6 = FIR_L;
	call (pc, _accumulateFIR)(DB);
	f5  = PASS f9, i2  = i5;
	f3  = PI;

/************************** High frequency range ****************/

	modify(i5, FIR_L*2+1);
	f1  = 0.0;						// _omega0;
	f3  = 0.19480023848390413;		// _omega1;

	lcntr = N_OCTAVE-CUTLINE, do (pc, calFIR_2) until lce;
		r6 = FIR_H;					// r6=-FIR_N:FIR_N in loop
		call (pc, _accumulateFIR)(DB);
		f5 = PASS f9, f9 = dm(i3, m3); 
		i2 = i5;
calFIR_2:
		f3 = f3 * f14, f1 = f3;

	r6 = FIR_H;
	call (pc, _accumulateFIR)(DB);
	f5  = PASS f9, i2  = i5;
	f3  = PI;

	f4  = 1.0/PI;
	modify(i5, -FIR_L*2-1);
	i2  = i5;
	i10 = i2;
	f8  = dm(i2, m6);
	f6  = f8 * f4, f8 = dm(i2, m6);
	lcntr = (FIR_L+FIR_H)*2+1, do (pc, 1) until lce;
		f6 = f8 * f4, f8 = dm(i2, m6), pm(i10, m14) = f6;
	pm(i10, m14) = f6;
	rts;

_calculateFIR.end:

/*
   _sinf/_cosf,      f0 = cosf(f4), f2, f8, f12 changed
   ___float_divide   f7=f7/f12, f0 changed

	f1 = dm(_omega0);
	f3 = dm(_omega1);
	f5 = dm(_ph0);
	f9 = dm(_ph1);
 */

_accumulateFIR:
	call (___float_divide)(DB);
	f7  = f9 - f5;						// (ph1-ph0)
	f12 = f3 - f1;						// (omega1-omega0)
	f14 = PASS f7, puts = f14;			// f14  slope rate
	
	r12 = r6 + r6;
	r12 = r12 + 1;
	lcntr = r12, do (pc, _accFIR1) until lce;
		f7 = FLOAT r6;
		f10 = f14 + f7;					// n_alpha
		f4 = ABS f10;
		COMP(f4, f13);
		if GE jump (pc, _accBig), else f4 = f14 * f1;
			//cos(ph0 - alpha*omega0)*(omega1 - omega0);
		f4 = f5 - f4,
		CCALL (_cosf);
		f4 = f3 - f1, f8 = dm(i2, m5);
		jump (pc, _accFIR2), f7 = f0 * f4;
_accBig:
          //sin(omega1*(taps-FIR_N)+ph1)-sin(omega0*(taps-FIR_N)+ph0)/n_alpha;
		f4 = f3 * f7;
		f4 = f4 + f9,
		CCALL (_sinf);
		f4 = f1 * f7, f7 = f0;
		f4 = f4 + f5,
		CCALL (_sinf);
		call (___float_divide)(DB);
		f7 = f7 - f0, f8 = dm(i2, m5);
		f12 = f10;
_accFIR2:
		f4 = f8 + f7;
_accFIR1:
		r6 = r6 - 1, dm(i2, m6) = f4;

	rts(DB);
	f14 = gets(1);
	alter(m6);
_accumulateFIR.end:

.global _convertHexToPhase;
/* m3 = channel
   i2, i10 -> HexPhaseData
   i4 -> predefinedPhase
*/
_convertHexToPhase:
	i2  = _HexPhaseData + 2;			// skip head, first byte
	i10 = _HexPhaseData + 3;			// second byte
	i4  = _predefinedPhase;
	modify(i4, m3);						// i4=&_predefinedPhase[chn]
	m3  = 2;
	f2  = 0.0001;
	r4  = dm(i2, m2), r8 = pm(i10, m10);	// load first
	r8  = r8 OR FDEP r4 by 8:8(SE);
	lcntr = N_OCTAVE, do(pc, 3) until lce;
		f8 = FLOAT r8;
		f6 = f8 * f2 , r4 = dm(i2, m2), r8 = pm(i10, m10);
		r8 = r8 OR FDEP r4 by 8:8(SE), dm(i4, m3) = f6;

	rts;
_convertHexToPhase.end:


.global _adjustPreWrap;
/* m3 = channel */
_adjustPreWrap:
	i2  = _predefinedPhase;
	i10 = _preWrap;
	modify(i2, m3);
	m3  = 2;
	lcntr = CUTLINE, do (pc, 3) until lce;
		f2 = dm(i2, m5), f4 = pm(i10, m14);
		f8 = f2 - f4;
		dm(i2, m3) = f8;
		
	rts;
_adjustPreWrap.end:


.global _smoothPhase;
/*
   convert phase range [-pi, +pi] to real (-\inf, +\inf)
   by adding or subtraction 2*pi period
   r0 = channel
 */
_smoothPhase:
	i4  = _predefinedPhase;
	r5  = r5 - r5, modify(i4, m3);		// f5=nPI, i4=&_predefinedPhase[chn]
	r10 = r10 - r10;
	f12 = 2.0*PI;
	m3  = 2;
	lcntr = N_OCTAVE, do(pc, validPhase) until lce;
		f8 = dm(i4, m5);
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
		f10 = PASS f8, dm(i4, m3) = f8;

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
	if NE rts;							//NE = invalid

	i2  = _HexPhaseData;
	r8  = N_OCTAVE*2+2;
	CCALL (_readFlash);					// read all include head

	m3  = r0;
	call (pc, _convertHexToPhase);
	rts, r6 = r6 - r6;					// EQ=valid
_loadFromFlash.end:

.global _initPhase;
_initPhase:
	i2  = _FIR_coeffs0;
	i10 = _FIR_coeffs0 + 1;
	r0  = 0;
	lcntr = @_FIR_coeffs0*2, do (pc, 1) until lce;	// clear coeffs0~~coeffs3
		dm(i2, m2) = r0, pm(i10, m10) = r0;

	call (pc, _loadFromFlash)(DB);
	r4  = 0;						// sector No.0
	r0  = 0;						// load as channel 0
	m3  = 0;
	call (pc, _adjustPreWrap);
	m3  = 0;
//	call (pc, _smoothPhase);
	r4  = 0;						// channel 0
	call (pc, _calculateFIR);
	call (pc, _loadFromFlash)(DB);
	r4  = 1;						// sector No.1
	r0  = 1;						// load as channel 1
	m3  = 1;
	call (pc, _adjustPreWrap);
	m3  = 1;
//	call (pc, _smoothPhase);
	r4  = 1;							// channel 1
	call (pc, _calculateFIR);

	f0 = 1.0;
	dm(_FIR_coeffs2+FIR_L) = f0;
	dm(_FIR_coeffs2+2*FIR_L+1+FIR_H) = f0;
	dm(_FIR_coeffs3+FIR_L) = f0;
	dm(_FIR_coeffs3+2*FIR_L+1+FIR_H) = f0;
	rts;
_initPhase.end:

