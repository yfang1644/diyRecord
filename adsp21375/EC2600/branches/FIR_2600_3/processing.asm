//////////////////////////////////////////////////////////////////////////////
//NAME:     processing.asm                                                  //
//DATE:     2015-05-10                                                      //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"

.global _samples, _inp_buf, _outp_buf;
.extern _FIR_coeffs0;
.extern ___float_divide;

.section/dm seg_dmda;

.var  _samples[] = 0x1234, 0x5678;
.var  _inp_buf[] = 0x1234, 0x5678, 0x8765, 0x4321;
.var _outp_buf[] = 0x1234, 0x5678, 0x8765, 0x4321, 0xaaaa, 0xbbbb;

.var _PTR_buffer0 = _FIR_buffer0;
.var _FIR_buffer0[2*FIR_N+1];
.var _PTR_buffer1 = _FIR_buffer1;
.var _FIR_buffer1[2*FIR_N+1];
.var _PTR_buffer2 = _FIR_buffer2;
.var _FIR_buffer2[2*FIR_N+1];
.var _PTR_buffer3 = _FIR_buffer3;
.var _FIR_buffer3[2*FIR_N+1];

.section/pm seg_pmco;

_fir_filtering:
	bit set MODE1 ALUSAT;				// FIX instruction needs saturation

	i12 = _FIR_coeffs0;
	i10 = _FIR_buffer0;

	i2  = _inp_buf;
	i8  = _outp_buf;
	r13 = 31;
	r14 = -31;
	r4  = dm(i2, m6);
	l4  = 2*FIR_N+1;
	lcntr = 4, do (pc, _fir_1) until lce;
		f4 = FLOAT r4 by r14, b4 = i10;
		i4 = pm(m15, i10);
		dm(i4, m6) = f4;
		r12 = r12 - r12, pm(m15, i10) = i4;
		r8 = r8 - r8, f2 = dm(i4, m6), f4 = pm(i12, m14);
		lcntr = 2*FIR_N, do (pc, 1) until lce;
			f12 = f2 * f4, f8 = f8 + f12, f2 = dm(i4, m6), f4 = pm(i12, m14);

		f12 = f2 * f4, f8 = f8 + f12;
		f8 = f8 + f12;

		r8 = FIX f8 by r13;
		r8 = ASHIFT r8 by -8;
		modify(i10, 2*FIR_N+2);
_fir_1:
		r4 = dm(i2, m6), pm(i8, m14) = r8;

	l4  = m5;
	rts;
_fir_filtering.end:


.global _digitalProcessing;
_digitalProcessing:
	// copy samples to inp_buf

	r4 = dm(_samples + 0);				// get SOURCE
	dm(_outp_buf + 4) = r4;
	r8 = LSHIFT r4 by 8;
	dm(_inp_buf + 0) = r8;
	dm(_inp_buf + 2) = r8;
	r4 = dm(_samples + 1);
	dm(_outp_buf + 5) = r4;
	r8 = LSHIFT r4 by 8;
	dm(_inp_buf + 1) = r8;
	dm(_inp_buf + 3) = r8;

	call _fir_filtering;

	rti(DB);
	bit clr MODE1 SRRFL|SRRFH|SRD1H|SRD1L|SRD2H|SRD2L;
	POP STS, FLUSH CACHE;

_digitalProcessing.end:

