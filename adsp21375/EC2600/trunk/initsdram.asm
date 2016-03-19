// Sets up the SDRAM controller to access SDRAM.

#include <def21375.h>
#include <sru.h>
#include "lib_glob.h"
#include "flash.h"

.section/pm seg_pmco;

.global _initSDRAM;
_initSDRAM:
	ustat1 = dm(SYSCTL);
	bit clr ustat1 MSEN;    //This setting allows SDRAM access
	bit clr ustat1 IRQ0EN;
	dm(SYSCTL) = ustat1;

	bit clr FLAGS FLG0;		// DQM of SDRAM

	DELAY(15000);

	// Programming SDRAM control registers.
	//===================================================================
	// RDIV = ((f SDCLK X t REF )/NRA) - (tRAS + tRP )
	// CCLK_SDCLK_RATIO=2.5
//	ustat1 = 1650 - 10; 	// (105.6 *(10^6)*64*(10^-3)/4096) - (7+3) = 1628
//	ustat1 = 1650 - 6;		// 105.6
	ustat1 = 1650-10;
	// Change this value to optimize the performance for quazi-sequential accesses (step > 1)
	#define SDMODIFY 1		// Setting the Modify to 1
	bit set ustat1 (SDMODIFY<<17)|SDROPT; // Enabling SDRAM read optimization
	dm(SDRRC) = ustat1;

	//
	// Configure SDRAM Control Register (SDCTL) for the Micron MT48LC4M32
	//
	//  SDCL3  : SDRAM CAS Latency= 3 cycles
	//  DSDCLK1: Disable SDRAM Clock 1
	//  SDPSS  : Start SDRAM Power up Sequence
	//  SDCAW8 : SDRAM Bank Column Address Width= 8 bits
	//  SDRAW12: SDRAM Row Address Width= 12 bits
	//  SDTRAS7: SDRAM tRAS Specification. Active Command delay = 7 cycles
	//  SDTRP3 : SDRAM tRP Specification. Precharge delay = 3 cycles.
	//  SDTWR2 : SDRAM tWR Specification. tWR = 2 cycles.
	//  SDTRCD3: SDRAM tRCD Specification. tRCD = 3 cycles.
	//
	//--------------------------------------------------------------------

	ustat1 = 0
			|SDNOBSTOP
			|SDRAW12
			|SDTRCD3
			|SDTWR1
			|X16DE
//			|SDSRF
			|SDPSS
			|SDCAW9
//			|SDPM
			|SDTRP2
			|SDTRAS4
			|DSDCLK1
			|SDCL2;
// SDPSS=1, SDBN=1(4bank) SDBS=7(bank3)
// SDTRP=2, SDTRAS=4, SDCL=2, SDPGS=1(512words/page)
	dm(SDCTL) = ustat1;

	ustat1 = WS2|HC1|BW16|AMIEN;
	dm(AMICTL0)= ustat1;

	// Mapping Bank 0 to SDRAM
	// Make sure that jumper is set appropriately so that MS0 is connected to
	// chip select of 16-bit SDRAM device
	ustat1 = dm(EPCTL);
	bit set ustat1 B0SD;
	bit clr ustat1 B1SD|B2SD|B3SD;
	bit clr ustat1 DATEN0|DATEN1;
	bit set ustat1 DATEN2|DATEN3;
	dm(EPCTL) = ustat1;

	//===================================================================
	//
	// Configure AMI Control Register (AMICTL) Bank 1 for the SST39VF040
	//
	//  WS23 : Wait States= 23 cycles
	//  AMIEN: Enable AMI
	//  BW8  : External Data Bus Width= 8 bits.
	//--------------------------------------------------------------------
	ustat1 = AMIEN|BW8|WS23|PKDIS;
	dm(AMICTL1) = ustat1;
	ustat1 = 0xf0;
//	dm(FLASH_START) = ustat1;		//Command for RESET of FLASH

	rts;
_initSDRAM.end:

