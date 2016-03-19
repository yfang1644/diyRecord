/**************************************************************************
* Function:   LOGF - Natural Logarithm
*
* Prototype:  float logf(float x);
*
* Operation: 
*             Valid input: x > 0 (MAKE SURE)
* Used registers: f0, f2, f4, f8, f12, f11=2.0
**************************************************************************/
#include "lib_glob.h"

.global  _logf;

.section/pm seg_pmco;

_logf:
		i4  = logs_data;				/* Point to data array          */
		f12 = abs f4;

		r2  = LOGB f4;
		r2  = r2 + 1;					/* Increment exponent           */

		r4  = -r2, r8 = dm(i4, m6);		/* Negate exponent              */
										/* and load C0                  */

		f12 = SCALB f12 by r4,			/* F12 = .5 <= f < 1            */
		f0  = dm(i4, m6);				/* and load 0.5                 */

		comp (f12, f8);					/* Compare f > C0               */

		if GT jump (pc, adjust_z) (db);
		f4 = f12 - f0;					/* znum = f - 0.5               */
		f8 = f4 * f0;					/* znum = znum * 0.5            */

		jump (pc, compute_r) (db);
		f12 = f8 + f0;					/* zden = znum * 0.5 + 0.5      */	
		r2  = r2 - 1;					/* N = N - 1                    */

adjust_z:	
		f4  = f4 - f0;					/* znum = f - 0.5 - 0.5         */	
		f8  = f12 * f0;					/* f * 0.5                      */
		f12 = f8 + f0;					/* zden = f * 0.5 + 0.5         */

compute_r:								/* Compute:  znum / zden */
		f0  = RECIPS f12, puts = r2;	/* Get 4 bit seed R0 = 1/D      */

		lcntr = 3, do (pc, divide_op) until lce;
			f12 = f0 * f12;
divide_op:	f4  = f0 * f4, f0  = f11 - f12;

		f2  = f0 * f4;					/* z = N * R0 * R1 * R2 * R3    */

		f0  = f2 * f2, f8 = dm(i4, m6);	/* w = z^2, and load b0         */

		f12 = f8 + f0, f8 = dm(i4, m6);	/* B(W) = w + b0, and load a1   */

		f4  = f8 * f0, f8 = dm(i4, m6);	/* w*a1, and load a0            */

		f4  = f4 + f8, f8 = f0;			/* A(W) = w * a1 + a0           */ 

		/* Compute : A(W) / B(W) */
		f0  = RECIPS f12;               /* Get 4 bit seed R0 = 1/D      */
		lcntr = 3, do (pc, divide_op2) until lce;
			f12 = f0 * f12;
divide_op2: f4  = f0 * f4, f0  = f11 - f12;

		f4  = f0 * f4;					/* w = N * R0 * R1 * R2 * R3   */
		f4  = f4 * f8;					/* Compute r(z^2)= w * A(w)/B(w)*/

compute_R:
		f4  = f2 * f4;					/* z * r(z^2)                   */

		f12 = f2 + f4, r8 = gets (1);	/* R(z) = z + z * r(z^2)        */
										/* and load N                   */

		f0  = float r8,	f4 = dm(i4, m6);/* F0 = X * N                   */  
										/* and load C2                  */

		f8  = f0 * f4, f4 = dm(i4, m6);	/* F8 = XN * C2                 */
										/* and load C1                  */
     
		f4  = f0 * f4, f0  = f8 + f12;	/* F4 = XN * C1                 */
										/* and F0 = XN * C2+R(z)        */

		f0  = f0 + f4, alter(m6);		/* f0 = ln(X)                   */ 
		EXIT;
_logf.end:

.section/dm seg_dmda;
.var logs_data[7] =      0.70710678118654752440,        /*C0 = sqrt(.5)*/
                         0.5,                           /*Constant used*/
                        -5.578873750242,                /*b0*/
                         0.1360095468621E-1,            /*a1*/
                        -0.4649062303464,               /*a0*/
                        -2.121944400546905827679E-4,    /*C2*/
                         0.693359375;                   /*C1*/

