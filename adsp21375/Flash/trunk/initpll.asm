///////////////////////////////////////////////////////////////////////////
// Sets up the SHARC's PLL
// CLKIN= 16.5 MHz, Multiplier= 32, Divisor= 2, CCLK_SDCLK_RATIO 2.5
///////////////////////////////////////////////////////////////////////////

#include <def21375.h>

.section/pm seg_pmco;

.global _initPLL;
_initPLL:
// CLKIN= 16.5 MHz, Multiplier= 32, Divisor= 2, CCLK_SDCLK_RATIO 2.5
// Core clock = (16.5MHz * 32)/2 = 264 MHz
	ustat3 = SDCKR2 | PLLM12| PLLD2|DIVEN;

	dm(PMCTL) = ustat3;
	bit set ustat3 PLLBP;
	bit clr ustat3 DIVEN;
	dm(PMCTL) = ustat3;

// Wait for at least 4096 cycles for the pll to lock
	lcntr = 5000, do (pc, 1) until lce;
		nop;

	ustat3 = dm(PMCTL);
	bit clr ustat3 PLLBP;
	bit set ustat3 CLKOUTEN;
	dm(PMCTL) = ustat3;

	rts;
_initPLL.end:

