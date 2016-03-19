/**************************************************************************
*
* Function:  SQRT -- Square root, sqrt(x), x>=0
* used registers: r0, r2, r4, r8, r12
*
**************************************************************************/
#include "lib_glob.h"

.section/pm seg_pmco;

.global _sqrtf;
_sqrtf:	f8  = 1.5;					/* f0=0.5X, as Evaluate constant C  */
//		r0 = r0 - r0;
//		f0 = (f4 + f0)/2;
		f2  = rsqrts f4;			/* Fetch seed X0                     */

		f12 = f2 * f0;				/* F12 = C * X0                      */
		f12 = f2 * f12;				/* F12 = X0 * (C * X0)               */
		f12 = f8 - f12;				/* F12 = 1.5 - (X0 * (C * X0))       */
		f2  = f2 * f12;				/* X1  = X0 * (1.5 - (X0 * (C * X0)))*/

		f12 = f2 * f0;				/* F12 = C * X1                      */
		f12 = f2 * f12;				/* F12 = X1 * (C * X1)               */
		f8  = f2 * f4, f12 = f8 - f12;/* F12 = 1.5 - (X1 * (C * X1))     */
		f0  = f8 * f12;				/* X2  = X1 * (1.5 - (X1 * (C * X1)))*/
									/* FX  = X2 * X                      */
		EXIT;
_sqrtf.end:

