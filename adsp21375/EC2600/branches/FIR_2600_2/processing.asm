//////////////////////////////////////////////////////////////////////////////
//NAME:     processing.asm                                                  //
//DATE:     2015-05-10                                                      //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.global _samples, _outp_buf;
.extern ___float_divide;
.extern _FIR_coeffs0;
.extern _crossHPF, _crossLPF, _smoothLPF;

.section/dm seg_dmda;
.var  _samples[] = 0x1234, 0x5678;
.var  _inp_buf[] = 0x1234, 0x5678, 0x8765, 0x4321;
.var _outp_buf[] = 0x1234, 0x5678, 0x8765, 0x4321, 0xaaaa, 0xbbbb;

.var _PTR_Lbuffer0 = _FIR_Lbuffer0;
.var _FIR_Lbuffer0[2*FIR_L+1];
.var _PTR_Lbuffer1 = _FIR_Lbuffer1;
.var _FIR_Lbuffer1[2*FIR_L+1];
.var _PTR_Lbuffer2 = _FIR_Lbuffer2;
.var _FIR_Lbuffer2[2*FIR_L+1];
.var _PTR_Lbuffer3 = _FIR_Lbuffer3;
.var _FIR_Lbuffer3[2*FIR_L+1];

.var _PTR_Hbuffer0 = _FIR_Hbuffer0;
.var _FIR_Hbuffer0[2*FIR_H+1]};
.var _PTR_Hbuffer1 = _FIR_Hbuffer1;
.var _FIR_Hbuffer1[2*FIR_H+1]};
.var _PTR_Hbuffer2 = _FIR_Hbuffer2;
.var _FIR_Hbuffer2[2*FIR_H+1]};
.var _PTR_Hbuffer3 = _FIR_Hbuffer3;
.var _FIR_Hbuffer3[2*FIR_H+1]};

.var _ptrcrossHPF0 = _crossHPFBuf0;
.var _crossHPFBuf0[CROSSN];
.var _ptrcrossHPF1 = _crossHPFBuf1;
.var _crossHPFBuf1[CROSSN];
.var _ptrcrossHPF2 = _crossHPFBuf2;
.var _crossHPFBuf2[CROSSN];
.var _ptrcrossHPF3 = _crossHPFBuf3;
.var _crossHPFBuf3[CROSSN];

.var _crossLPFBuf0[8];
.var _crossLPFBuf1[8];
.var _crossLPFBuf2[8];
.var _crossLPFBuf3[8];
.var _smoothLPFBuf0[10];
.var _smoothLPFBuf1[10];
.var _smoothLPFBuf2[10];
.var _smoothLPFBuf3[10];

.section/dm seg_dmda1;
.var _ptrHFbuf0 = _HFbuffer0;
.var _HFbuffer0[HF_DELAY];
.var _ptrHFbuf1 = _HFbuffer1;
.var _HFbuffer1[HF_DELAY];

.section/pm seg_pmco;

/*****************************************************************
Cascaded IIR Biquad Sections
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

//  { --- comments for subroutine called cascaded_biquad ---               }
//  {TERMINOLOGY: w' = w(n-1), w" = w(n-2), NEXT = "of next biquad section"}
//  { #1    clear f12,            rd w",       rd a2         loop prologue }
//  { #2    for each section, do:                                          }
//  { #3    w"a2, 1st=x+0,else=y, rd w',       rd a1         loop body     }
//  { #4    w'a1, x+w"a2,         wr new w',   rd b2         loop body     }
//  { #5    w"b2, new w,          rd NEXT w",  rd b1         loop body     }
//  { #6    w'b1, new w+(w"b2),   wr new w,    rd NEXT a2    loop body     }
//  { #7    calc last y after dropping out of loop           loop epilogue }

	(m2 = 2)
	i4 ->delay line buffer
	i12->IIR coefficients
	r6  = order
	f8  = input value
return : f8 = IIR(f8, coeffs, r6);
changed registers: r2, r3, r4, r8, r12
***********************************************************************/
_biQuadIIR:
	r12 = r12 - r12, f2 = dm(i4, m6), f4 = pm(i12, m14);
	lcntr = r6, do (pc, 4) until lce;
		f12 = f2 * f4, f8 = f8 + f12, f3 = dm(i4, m7), f4 = pm(i12, m14);
		f12 = f3 * f4, f8 = f8 + f12, dm(i4, m2) = f3, f4 = pm(i12, m14);
		f12 = f2 * f4, f8 = f8 + f12, f2 = dm(i4, m7), f4 = pm(i12, m14);
		f12 = f3 * f4, f8 = f8 + f12, dm(i4, m2) = f8, f4 = pm(i12, m14);

	f8  = f8 + f12;
	rts, f8 = f8 * f4;			// gain
_biQuadIIR.end:


/*********************************************************************
 transversal FIR

	i10->delay line buffer
	i12->IIR coefficients
	r6  = order
	f8  = input value
	buffer[0] holds offset, real buffer starts at buffer[1]
return : f8 = FIR(f8, coeffs, r6);
changed registers: r2, r4, r8, r12
**********************************************************************/
_transversalFIR:
	b4  = i10;					// set B will automatically load I=B
	i4  = pm(m15, i10);			// load pointer
	r6  = r6 - 1, l4 = r6;
	r8  = r8 - r8, dm(i4, m6) = f8;
	pm(m15, i10) = i4;			// restore pointer

	r12 = r12 - r12, f2 = dm(i4, m6), f4 = pm(i12, m14);
	lcntr = r6, do (pc, 1) until lce;
		f12 = f2 * f4, f8 = f8 + f12, f2 = dm(i4, m6), f4 = pm(i12, m14);

	rts(DB), f12 = f2 * f4, f8 = f8 + f12;
	f8 = f8 + f12;
	l4  = m5;
_transversalFIR.end:


/* output F8 */
_highpass:
	r6  = CROSSN;
	i12 = _crossHPF;					// coeffs
	r4  = @_crossHPFBuf0;
	r4  = r4 * r0(UUI), f8 = f7;
	m8  = r4;
	call (pc, _transversalFIR)(DB);		// crossover
	i10 = _crossHPFBuf0;				// buffer
	modify(i10, m8);

	r6  = FIR_H*2+1;
	r4  = @_FIR_Hbuffer0 + 1;
	r4  = r4 * r0(UUI);
	m8  = r4;
	i10 = _FIR_Hbuffer0;
	modify(i10, m8);					// buffer
	r4  = @_FIR_coeffs0;
	r4  = r4 * r0(UUI);
	m8  = r4;
	call (pc, _transversalFIR)(DB);		// phase compensation
	i12 = _FIR_coeffs0 + 2*FIR_L + 1;
	modify(i12, m8);					// coeffs
	
	r4  = @_HFbuffer0 + 1;
	r4  = r4 * r0(UUI);
	m8  = r4;
	i10 = _HFbuffer0;					// save high-freq in delay buffer
	modify(i10, m8);
	b4  = i10;
	i4  = pm(m15, i10);
	l4  = HF_DELAY;
	f10 = dm(i4, m5);					// load hf(n-DELAY)
	dm(i4, m6) = f8;
	pm(m15, i10) = i4;
	l4  = m5;

	rts;
_highpass.end:


_lowpass:
	r6  = 4;
	i12 = _crossLPF;					// coeffs
	r4  = @_crossLPFBuf0;
	r4  = r4 * r0(UUI), f8 = f7;
	m4  = r4;
	call (pc, _biQuadIIR)(DB);			// crossover
	i4  = _crossLPFBuf0;				// buffer
	modify(i4, m4);

	r4  = FEXT r15 by 0:4;
	if not SZ jump(pc, _lowpass_1), r8 = r8 - r8;		// 1/16 decimation

	r6  = FIR_L*2+1;
	r4  = @_FIR_Lbuffer0 + 1;
	r4  = r4 * r0(UUI);
	m8  = r4;
	i10 = _FIR_Lbuffer0;
	modify(i10, m8);					// buffer
	r4  = @_FIR_coeffs0;
	r4  = r4 * r0(UUI);
	m8  = r4;
	call (pc, _transversalFIR)(DB);		// phase compensation
	i12 = _FIR_coeffs0;
	modify(i12, m8);					// coeffs

_lowpass_1:
	i4  = _inp_buf;
	dm(m3, i4) = f8;
	rts;
_lowpass.end:


_compose:
	f4  = 16.0;
	i4  = _inp_buf;
	f8  = dm(m3, i4);
	f8  = f8 * f4;

	r6  = 5;
	i12 = _smoothLPF;					// coeffs
	r4  = @_smoothLPFBuf0;
	r4  = r4 * r0(UUI);
	m4  = r4;
	call (pc, _biQuadIIR)(DB);
	i4  = _smoothLPFBuf0;				// buffer
	modify(i4, m4);
	
	rts, f8  = f8 + f10;				// f10=high-freq(delayed)
_compose.end:


.global _digitalProcessing;
_digitalProcessing:
	r1  = 31;
	r0  = 0;
	lcntr = 2, do (pc, _processing1) until lce;
		i2 = _samples;					// copy samples to inp_buf
		m3 = r0;
		r8 = dm(m3, i2);				// get SOURCE

		i2 = _outp_buf + 4;				// OUT_E=IN0, OUT_F=IN1
		r1 = -r1, dm(m3, i2) = r8;
		r8 = LSHIFT r8 by 8;
		f8 = FLOAT r8 by r1;
		i2 = _inp_buf;
		r1 = -r1, dm(m3, i2) = f8;

		f7 = f8;
		call _lowpass;					// save in buffer
		call _highpass;					// output f8
		call _compose;					// output f8

		bit set MODE1 ALUSAT;			// FIXed saturation
		r8  = FIX f8 by r1;
		r8  = ASHIFT r8 by -8;
		i2 = _outp_buf;
_processing1:
		r0 = r0 + 1, dm(m3, i2) = r8;

	dm(_outp_buf + 2) = m5;				// OUT_C=OUT_D=0
	dm(_outp_buf + 3) = m5;

	r15 = r15 + 1;
	
	rti(DB);
	bit clr MODE1 SRRFL|SRRFH|SRD1H|SRD1L|SRD2H|SRD2L;
	POP STS, FLUSH CACHE;

_digitalProcessing.end:

