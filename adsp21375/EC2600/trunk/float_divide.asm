/*  This routine performs a floating point division
    in the current precision mode of the processor.

    Calling Parameters
	F12 contains the Denominator
	F11 contains the value 2.0;
	F7  contains the Numerator

    Return Registers
	F7  contains the Quotient

    Altered Registers
	F0, F7, F12

    Cycle Count
	8 cycles
*/
#include "lib_glob.h"

.section/pm seg_pmco;

.global	___float_divide;

___float_divide:
		F0 = RECIPS F12;	    		/*Get 4 bit seed R0=1/D*/
		F12 = F0 * F12;					/*D' = D*R0*/
		F7 = F0 * F7, F0 =F11 - F12;	/*F0=R1=2-D', F7=N*R0*/
		F12 = F0 * F12;					/*F12=D'=D'*R1*/
		F7 = F0 * F7, F0 = F11 - F12;	/*F7=N*R0*R1, F0=R2=2-D'*/
		RTS (DB), F12 = F0 * F12;		/*F12=D'=D'*R2*/
		F7 = F0 * F7, F0 = F11 - F12;	/*F7=N*R0*R1*R2, F0=R3=2-D'*/
		F7 = F0 * F7;					/*F12=N*R0*R1*R2*R3*/
___float_divide.end:

/*
	This routine performs a integer division by 10.
	(r0, r8) = r8 / 10;
	r0 = Quotient
	r8 = reminder

    Changed Registers: r0, r8. r4 unchanged
*/

.global	_div10;
_div10:
	r0 = 10;
	r4 = r4 - r4, puts = r4;			// r0 = 0
	lcntr = 10, do (pc, 5) until lce;
		r8 = r8 - r0;
		if LT jump (pc, div10_over)(LA), r8 = r8 + r0;
		r4 = r4 + 1;
		nop;
		nop;

div10_over:
	r0 = pass r4, r4 = gets(1);
	alter(1);
	EXIT;
_div10.end:

