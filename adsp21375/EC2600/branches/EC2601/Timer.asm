//////////////////////////////////////////////////////////////////////////////
//NAME:     Timer.asm
//DATE:     2010-08-12
//
//USAGE:    Sets up the Core Timer and High Priority Interrupt
//          for the panel switch and flash digit, and other schedules
//////////////////////////////////////////////////////////////////////////////

#include <def21375.h>
#include "constant.h"

.section/pm seg_pmco;

.global _initTimer;
_initTimer:
	TPERIOD = _1MS * 10;				// Timer interrupt 10ms for switch
	TCOUNT = _1MS * 10;
	rts(DB);
	bit set MODE2 TIMEN;				// enable core timer
	bit set IMASK TMZLI;				// enable low priority timer interrupt
_initTimer.end:

