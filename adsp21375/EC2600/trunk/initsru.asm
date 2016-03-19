/*****************************************************************************
**
**  File: initSRU.asm
**  Date: 2010-08-15
**  Use:  ADSP-21375/EC2600. Initializes the SRU & DAI/DPI pins
**
******************************************************************************/

#include <def21375.h>
#include <sru.h>
#include "lib_glob.h"

.section /pm seg_pmco;

.global _initSRU;
_initSRU:

	r0 = 0x000FFFFF;
	dm(DAI_PIN_PULLUP) = r0;		// Disable all 20 DAI pins(pullup input)

	//===================================================================
	// DAI initialize
	// route ADC/DAC signals
	// ADC works in master mode, ADC bit clock and LR clock -> DSP
	//		DAI06 -- ADC MCLK(unused)
	//		DAI07 -- ADC bit clock
	//		DAI08 -- ADC LR clock(sampling rate)
	//		DAI05 -- ADC data(SPORT1A)
	//
	// DAC works in slave mode, clocked by DSP(can be controlled by ADC)
	//		DAI13 -- DAC1 bit clock (DSP output to DAC)
	//		DAI14 -- DAC1 LR clock (DSP output to DAC)
	//		DAI12 -- DAC1 data(SPORT2B)
	//		DAI15 -- DAC2 and DAC3 bit clock (DSP output to DAC)
	//		DAI16 -- DAC2 and DAC3 LR clock (DSP output to DAC)
	//		DAI11 -- DAC2 data(SPORT3A)
	//		DAI10 -- DAC3 data(SPORT3B)
	//
	// ADC and DAC reset pin DAI04
	//------------------------------------------------------------------
	SRU(LOW, DAI_PB06_I);			// ADC MCLK
	SRU(LOW, PBEN06_I);				// set input(no need to connect DSP)

	SRU(LOW, DAI_PB07_I);			// set LOW
	SRU(LOW, DAI_PB08_I);
	SRU(LOW, DAI_PB05_I);

	SRU(DAI_PB07_O,SPORT1_CLK_I);	// bit clock
	SRU(DAI_PB08_O,SPORT1_FS_I);	// LR clock
	SRU(DAI_PB05_O,SPORT1_DA_I);	// ADC input

	SRU(LOW, PBEN07_I);				// enable input
	SRU(LOW, PBEN08_I);
	SRU(LOW, PBEN05_I);

	SRU(DAI_PB07_O, SPORT2_CLK_I);	// bit clock
	SRU(DAI_PB07_O, SPORT3_CLK_I);	// bit clock
	SRU(DAI_PB07_O, DAI_PB13_I);	// bit clock to DAC1
	SRU(DAI_PB07_O, DAI_PB15_I);	// bit clock to DAC2 and DAC3
	SRU(HIGH, PBEN13_I);			// clock output enable
	SRU(HIGH, PBEN15_I);			// clock output enable

	SRU(DAI_PB08_O, SPORT2_FS_I);	// bit clock
	SRU(DAI_PB08_O, SPORT3_FS_I);	// bit clock
	SRU(DAI_PB08_O, DAI_PB14_I);	// LR clock to DAC1
	SRU(DAI_PB08_O, DAI_PB16_I);	// LR clock to DAC2 and DAC3
	SRU(HIGH, PBEN14_I);			// LR clock enable
	SRU(HIGH, PBEN16_I);			// LR clock enable

	SRU(SPORT3_DB_O,DAI_PB12_I);	// DAC1 data out
	SRU(HIGH, PBEN12_I);
	SRU(SPORT2_DB_O,DAI_PB10_I);	// DAC2 data out
	SRU(HIGH, PBEN10_I);
	SRU(SPORT3_DA_O,DAI_PB11_I);	// DAC3 data out
	SRU(HIGH, PBEN11_I);

	SRU(HIGH, PBEN04_I);			// ADC and DAC reset
	SRU(LOW, DAI_PB04_I);			// reset LOW
	DELAY(30000);
	SRU(HIGH, DAI_PB04_I);			// normal state HIGH

	//===================================================================
	// route UART signals
	//-------------------------------------------------------------------
	SRU2(UART0_TX_O, DPI_PB09_I);		// UART transmit signal is connected
	SRU2(HIGH, DPI_PBEN09_I);			// to DPI pin 9

	SRU2(DPI_PB10_O, UART0_RX_I);		// DPI10 as UART0 Rx
	SRU2(LOW, DPI_PB10_I);				// to the UART0 receive
	SRU2(LOW, DPI_PBEN10_I);			// enable DPI10 as input

	//===================================================================
	//
	// Route SPI signals to SPI FLASH
	//-------------------------------------------------------------------
	SRU(SPI_MOSI_O,DPI_PB01_I);			// MOSI to DPI01
	SRU(SPI_MOSI_PBEN_O, DPI_PBEN01_I);	// SData In
	SRU(DPI_PB02_O, SPI_MISO_I);		// DPI PB2 to MISO
	SRU(SPI_MISO_PBEN_O, DPI_PBEN02_I);	// SData Out
	SRU(SPI_CLK_O, DPI_PB03_I);			// SPI CLK to DPI03
	SRU(SPI_CLK_PBEN_O, DPI_PBEN03_I);	// clock out
	SRU(SPI_FLG0_O, DPI_PB05_I);		// SPI FLAG0 to DPI05
	SRU(SPI_FLG0_PBEN_O, DPI_PBEN05_I);	// Flag0 out as CS_

	//===================================================================
	//
	// Route SPIB signals to Panel(MAX7301AAX)
	//-------------------------------------------------------------------
	SRU(SPIB_MOSI_O,DPI_PB07_I);	//Connect MOSI(DSP in) to DPI PB7, from 7301 DOUT
	SRU(DPI_PB06_O, SPIB_MISO_I);	//Connect DPI PB6 to MISO(DSP), to 7301 DIN
	SRU(SPIB_CLK_O, DPI_PB08_I);	//Connect SPI CLK to DPI PB8.
	SRU(SPIB_FLG1_O, DPI_PB04_I);	//Connect SPI FLAG0 to DPI PB4(7301 CS).
//---------------------------------------------------------------------------
// Tie pin buffer enable from SPI peipherals to determine whether they are
// inputs or outputs

	SRU(SPIB_MOSI_PBEN_O, DPI_PBEN07_I);
	SRU(SPIB_MISO_PBEN_O, DPI_PBEN06_I);
	SRU(SPIB_CLK_PBEN_O, DPI_PBEN08_I);
	SRU(SPIB_FLG1_PBEN_O, DPI_PBEN04_I);

	SRU(FLAG8_O, DPI_PB14_I);			// Drive DPI13 with Flag 8
	SRU(FLAG9_O, DPI_PB13_I);			// Drive DPI14 with Flag 9
	SRU(HIGH, DPI_PBEN14_I);			// Flag8 and Flag9 output
	SRU(HIGH, DPI_PBEN13_I);

	rts;
_initSRU.end:

