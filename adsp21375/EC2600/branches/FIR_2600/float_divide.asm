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
		F7 = F0 * F7, F0 = F11 - F12;	/*F0=R1=2-D', F7=N*R0*/
		F12 = F0 * F12;					/*F12=D'=D'*R1*/
		F7 = F0 * F7, F0 = F11 - F12;	/*F7=N*R0*R1, F0=R2=2-D'*/
		RTS (DB), F12 = F0 * F12;		/*F12=D'=D'*R2*/
		F7 = F0 * F7, F0 = F11 - F12;	/*F7=N*R0*R1*R2, F0=R3=2-D'*/
		F7 = F0 * F7;					/*F12=N*R0*R1*R2*R3*/
___float_divide.end:

