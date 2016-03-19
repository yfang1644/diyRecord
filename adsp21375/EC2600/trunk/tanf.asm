/**************************************************************************
*
* Function:   TAN - Tangent
*
* Prototype:  float tanf(float x);
*
* Operation:  Based on an algorithm by Cody and Waite
*
*             Valid input: |x| < (2^20 * pi/2) [~ 1,647,099]
*             f0 = tanf(f4);
*
*
**************************************************************************/
#include "lib_glob.h"

.extern ___float_divide;

.global _tanf;
.segment /pm seg_pmco;


/**************************************************************************
* TANF()
**************************************************************************/

_tanf:

  /*
   *   N  = INTRND( x * 2/pi ) = FIX( x * 2/pi )
   *   XN = FLOAT( N )
   *   f  = ( X1 - XN * C1 ) + X2 ) - XN * C2,
   *
   *          where
   *            X1 = AINT ( x ) = FLOAT ( TRUNC ( x ) )
   *            X2 = x - X1
   */

		i4  = tan_cot_data;
		r8 = TRUNC f4;
		f0 = FLOAT r8;					/* Compute X1                */
		f8 = f4 - f0, f7 = dm(i4, m6);	/* Compute X2, Load 2/PI    */
		f7 = f4 * f7;					/* x*2/pi                    */
		r2 = fix f7, f12  = dm(i4, m6);	/* Compute N , Load C1    */
		f3 = float r2, f7 = dm(i4, m6);	/* Compute XN,  Load C2   */
		f12 = f3 * f12;
		f12 = f0 - f12;					/* XN * C1,  X1 - XN * C1 */

		f7 = f3 * f7, f8 = f8 + f12,	/* XN * C2, ( X1 - XN * C1 ) + X2  */
		f12 = dm(i4, m6);				/* load 1.0 for division           */
		f7 = f8 - f7, f3 = dm(i4, m6);	/* Compute f (= XNUM), Load eps    */

  /*
   *   If |f| >= eps
   *     XNUM = f * P(g) = p1 * g * f + p0 * f
   *     XDEN = Q(g)     = ( q2 * g + q1 ) * g + q0
   *
   *     where
   *          g  = f * f
   *          p0 = 1.0
   *
   *   else
   *     go directly to divide_op to avoid underflow in division
   */

		f8 = abs f7;
		comp(f8, f3);
		if lt jump(pc, divide_op);

		f0 = f7 * f7, f12 = dm(i4, m6);	/* Compute g, Load q2      */

		f8 = f12 * f0, f12 = dm(i4, m6);	/* q2 * g, Load q1          */

		f3  = f0 * f7,			/* g * f                               */
		f8  = f8 + f12,			/* q2 * g + q1                         */
		f12 = dm(i4, m6);		/* Load q0                             */

		f8 = f8 * f0, f4 = dm(i4, m6);	/* ( q2 * g + q1 ) * g, load p1    */

		f3 = f3 * f4,			/* p1 * g * f                          */
		f8 = f8 + f12;			/* ( q2 * g + q1 ) * g + ( 0.5 * q0 )  */

		f12 = f8 + f12;			/* Compute Q(g) (=XDEN)                */

		f7 = f3 + f7;			/* Compute f * P(g) (=XNUM)            */

divide_op:
		btst r2 by 0;			/* Test for N even / odd               */

		call (pc, ___float_divide) (db);
		if not sz f0  = pass f7, f7 = f12;
		if not sz f12 = -f0;

		f0 = pass f7;
		EXIT;
_tanf.end:

.segment /dm seg_dmda;

.var tan_cot_data[] =
			 0.63661977236758134308,	/* 2/PI                             */
			 1.5703125,					/* C1                               */
			 4.83826794897E-04,			/* C2 so that C + C2 = PI/2         */
			 1.0,						/* 1/2 Constant for __float_divide()*/
			 9.536743164E-7,			/* EPS                              */
			 0.971685835E-2,			/* Q2                               */
			-0.429135777,				/* Q1                               */
			 0.5,						/* Q0                               */
			-0.958017723E-1;			/* P1                               */

