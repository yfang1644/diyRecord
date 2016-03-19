//////////////////////////////////////////////////////////////////////////////
//NAME:     memory.asm                                                //
//DATE:     2015-05-23                                                      //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include <sru.h>

#include "lib_glob.h"

.section/pm seg_pmco;
.global _initFLASH;
_initFLASH:
	//===================================================================
	//
	// Configure AMI Control Register (AMICTL) Bank 1 for the SST39VF040
	//
	//  WS23 : Wait States= 23 cycles
	//  AMIEN: Enable AMI
	//  BW8  : External Data Bus Width= 8 bits.
	//--------------------------------------------------------------------
	r0 = AMIEN|BW8|WS23|PKDIS;
	dm(AMICTL1) = r0;
	DELAY(4000);

	rts;
_initFLASH.end:

