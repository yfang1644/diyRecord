//////////////////////////////////////////////////////////////////////////////
//NAME:     panel.asm                                                       //
//DATE:     2010-09-15                                                      //
//                                                                          //
//USAGE:    This file contains the setup routine for panel LEDs and switches//
//          interrupt service routine for handling IRQ1                     //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////

#include <def21375.h>
.global _panelInitTable, _flashOK, _flashError;
.global _initPanel, _updatePanel;
.section/dm seg_dmda;

.var _panelInitTable[] =
			// IC2     IC1     IC0
			0x0955, 0x0955, 0x0955,		// output 3*4
			0x0a55, 0x0a55, 0x0a55,		// output 3*4
			0x0b55, 0x0b55, 0x0b55,		// output 3*4
			0x0c55, 0x0c55, 0x0c55,		// output 3*4
			0x0d55, 0x0d55, 0x0d55,		// output 3*4
			0x0eff, 0x0e55, 0x0e55,		// input 4, output 2*4,
			0x0f7f, 0x0f55, 0x0f55,		// output 1, input 3, output 2*4
			0x067f, 0x0600, 0x0600,		// mask register
			0x0481, 0x0401, 0x0401;

// IC2:	2个8段管(P8-P15, P16-P23)，7个switches(P24-P30, P31输出中断)
//		P4:Program, P5:Status, P6:Remote/IO, P7:Lock
// IC1:	P4-10:Out2 Volume, P11-17:Out3 Volume, P18-24:Out4 Volume
//		P25-31:Out5 Volume (OutVolume:Limiter-Over-6dB-10dB-20dB-40dB-Mute)
// IC0: P4-10: In0 Volume, P11-17: In1 Volume, P18-24:Out0 Volume
//		P25-31:Out1 Volume (InVolume:Comp-Over-6dB-10dB-20dB-40dB-Mute)

.var _flashOK[] = // All LED off, display 'EC'
			0x40ff, 0x43ff, 0x43ff,
			0x4886, 0x4bff, 0x4bff,
			0x50c6, 0x52ff, 0x52ff,
			0x0000, 0x59ff, 0x59ff;

.var _flashError[] = // All LED on, display 'FF'
			0x4000, 0x4300, 0x4300,
			0x488e, 0x4b00, 0x4b00,
			0x508e, 0x5200, 0x5200,
			0x0000, 0x5900, 0x5900;

.section/pm seg_pmco;

wait_for_SPIFE:
	ustat1 = dm(SPISTATB);
	bit tst ustat1 SPIFE;
	if not TF jump (pc, -2);
	rts;
wait_for_SPIFE.end:

/*
	output commands and settings to MAX7301AAX(3 ICs)
	i4: pointer
	r4: one group of setting
*/
_updatePanel:
	lcntr = r4, do (pc, setMax7301) until lce;
		ustat1 = 0xFD02;			// SPIFLGB register to FLAG1(0xFD02)
		dm(SPIFLGB) = ustat1;
		call wait_for_SPIFE(DB);
		r0 = dm(i4, m6);
		dm(TXSPIB) = r0;

		call wait_for_SPIFE(DB);
		r0 = dm(i4, m6);
		dm(TXSPIB) = r0;

		call wait_for_SPIFE(DB);
		r0 = dm(i4, m6);
		dm(TXSPIB) = r0;

		ustat1 = 0xFF02;
setMax7301:
		dm(SPIFLGB) = ustat1;

	rts;
_updatePanel.end:

.global _initPanel;
_initPanel:
    r0 = 0;
    dm(SPIFLGB) = r0;
    dm(SPICTLB) = r0;

	// Pclk(peripheral clock=core clock/2)
	// min. clock of MAX7301 is 38.4ns, about 26MHz
	// baud rate = Pclk/divisor
	r0 = 8;							// Setup the baud rate
	dm(SPIBAUDB) = r0;

	ustat1 = 0						// Set the SPIB control register
			|SPIEN					// enable the port
			|SPIMS					// DSP as SPI master
			|MSBF					// MSB first
			|CLKPL					// clock polarity
			|CPHASE					// send CS_ manually
			|WL16					// word length = 16 bits
			|TIMOD1;
    dm(SPICTLB) = ustat1;

	rts;

_initPanel.end:

