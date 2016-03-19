//////////////////////////////////////////////////////////////////////////////
//NAME:		initSRU.asm
//DATE:		2010-09-15
//PURPOSE:	Program the SPI Flash for the ADSP-21375/EC2600
//
//USAGE:	This file initializes SRU for SPI on the ADSP-21375
//
//////////////////////////////////////////////////////////////////////////////
#include <def21375.h>
#include <sru.h>

.section/pm seg_pmco;

.global _initSRU;
_initSRU:
// Disable the pull-up resistors on all 20 pins
	r0 = 0x000FFFFF;
	dm(DAI_PIN_PULLUP) = r0;

	//===================================================================
	//
	// Route SPIB signals to Panel(MAX7301AAX)
	//
	//-------------------------------------------------------------------

	SRU(SPIB_MOSI_O,DPI_PB07_I);    //Connect MOSI(DSP in) to DPI PB7, from 7301 DOUT
	SRU(DPI_PB06_O, SPIB_MISO_I);   //Connect DPI PB6 to MISO(DSP), to 7301 DIN
	SRU(SPIB_CLK_O, DPI_PB08_I);    //Connect SPI CLK to DPI PB8.
	SRU(SPIB_FLG1_O, DPI_PB04_I);   //Connect SPI FLAG0 to DPI PB4(7301 CS).
	//===================================================================
	//
	// Setup SPI pins as inputs or outputs
	//
	//-------------------------------------------------------------------

	SRU(SPIB_MOSI_PBEN_O, DPI_PBEN07_I);
	SRU(SPIB_MISO_PBEN_O, DPI_PBEN06_I);
	SRU(SPIB_CLK_PBEN_O, DPI_PBEN08_I);
	SRU(SPIB_FLG1_PBEN_O, DPI_PBEN04_I);

	rts;
_initSRU.end:

