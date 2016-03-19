/* Sets up the SHARC's PCG
   CLKIN= 16.5 MHz
*/

#define CLKD_DIVIDER1	4		// BCK=4.125MHz
#define FSD_DIVIDER1	256		// FS=64.453KHz @CLKIN=16.5MHz
#define PHASE (15<<20)

#include <def21375.h>
#include "lib_glob.h"

.section/pm seg_pmco;

.global _initPCG;
_initPCG:
	r0 = CLKD_DIVIDER1 | PHASE;
	dm(PCG_CTLA1) = r0;					// bit clock=16.5/4=4.125MHz
	r0 = FSD_DIVIDER1 | ENFSA | ENCLKA;
	dm(PCG_CTLA0) = r0;					// frame sync=16.5/256=64.453MHz
 	DELAY(1000);
	rts(DB), r0 = r0 - r0;
	dm(PCG_PW1) = r0;
	dm(PCG_SYNC1) = r0;
_initPCG.end:
 
