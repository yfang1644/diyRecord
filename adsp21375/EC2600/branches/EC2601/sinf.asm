/***********************************************************************
 *		This subroutine computes the Sine or Cosine functions.
 *
 *		float sinf(float x);        <Prototype>
 *		float cosf(float x);        <Prototype>
 *
 *		If |x| > (2^20 * pi/2) [~ 1,647,099], return 0
************************************************************************/
#include "constant.h"
#include "lib_glob.h"

.section/pm seg_pmco;

.global _sinf, _cosf;

_cosf:
			f2 = PI/2;
			f4 = f2 - f4;					/* cos(x) = sin(pi/2 - x)   */

_sinf:		i4 = sine_data;
			f8 = ABS f4, f2 = dm(i4, m6);	/*f4 hold sign, load 1/PI   */
			f7 = f8 * f2, puts = r7;		/*Compute fp modulo value   */

			r2 = TRUNC f7, f12 = dm(i4, m6);/*Round nearest fractional portion*/
			BTST r2 BY 0;                   /*Test for odd number      */
			if not SZ f4 = -f4;				/*Invert sign if odd modulo*/
			f7 = FLOAT r2;					/*Return to fp*/

			/* Compute F */
			f12 = f12 * f7, f2 = dm(i4, m6);/*Compute XN*C1*/
			f2 = f2 * f7, f12 = f8 - f12;	/*Compute |X|-XN*C1, and XN*C2*/
			f8 = f12 - f2, f7 = dm(i4, m6);	/*Compute f=(|X|-XN*C1)-XN*C2*/
			f12 = ABS f8;					/*Need magnitude for test*/
			f7 = f12 - f7;					/*Check for sin(x)=x*/
			if LT jump (pc, compute_sign);	/*Return with result in F0*/

			/* Compute R */
			f12 = f12 * f12, f7 = dm(i4, m6);
			lcntr = 6, do (pc, 2) until lce;
				f7 = f12 * f7, f2 = dm(i4, m6);/*Compute sum*g*/
				f7 = f2 + f7;				/*Compute sum=sum+next r*/

			f7 = f12 * f7;					/*Final multiply by g*/
			f7 = f7 * f8;					/*Compute f*R*/
			f12 = f7 + f8;					/*Compute Result=f+f*R*/

compute_sign:
			f0 = f12 copysign f4, r7 =gets(1);	/*Restore sign of result*/
			f0 = RND f0, alter(m6);
			EXIT;
._sinf.end:
._cosf.end:


.section/dm seg_dmda;

.var sine_data[11] = 0.31830988618379067154,        /*1/PI*/
			 		 3.14160156250000000000,        /*C1, almost PI*/
					-8.908910206761537356617E-6,    /*C2, PI=C1+C2*/
					 9.536743164E-9,                /*eps, sin(eps)=eps*/
					-0.737066277507114174E-12,      /*R7*/
					 0.160478446323816900E-9,       /*R6*/
					-0.250518708834705760E-7,       /*R5*/
					 0.275573164212926457E-5,       /*R4*/
					-0.198412698232225068E-3,       /*R3*/
					 0.833333333327592139E-2,       /*R2*/
					-0.166666666666659653;          /*R1*/
