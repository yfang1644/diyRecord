/* Sets up the SHARC's PLL
   CLKIN= 16.5 MHz, Multiplier= 30, Divisor= 2, CCLK_SDCLK_RATIO 2.5
*/

#include <def21375.h>
#include "lib_glob.h"

.section/pm seg_pmco;

.global _initPLL;
_initPLL:

// CLKIN= 16.5 MHz, Multiplier= 30, Divisor= 2, CCLK_SDCLK_RATIO 2.5
// Core clock = (16.5MHz * 30)/2 = 247.5 MHz
	ustat1 = SDCKR2 | PLLM30 | PLLD2 | DIVEN;
	dm(PMCTL) = ustat1;
	bit set ustat1 PLLBP;
	bit clr ustat1 DIVEN;
	dm(PMCTL) = ustat1;

	// Wait for at least 4096 cycles for the pll to lock
	DELAY(10000);

	ustat1 = dm(PMCTL);
	bit clr ustat1 PLLBP;
	bit set ustat1 CLKOUTEN;
	dm(PMCTL) = ustat1;

	rts;
_initPLL.end:
