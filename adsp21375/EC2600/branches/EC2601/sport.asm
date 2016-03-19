////////////////////////////////////////////////////////////////////////////
//NAME:     sport.asm                                                     //
//DATE:     2010-10-05                                                    //
//USAGE:    Transmit and receive serial ports(SPORT) initialization and   //
//          ISR. It uses SPORT0 to receive data from the ADC and transmits//
//          the data to the DAC's via SPORT1A, SPORT1B, SPORT2A, SPORT2B. //
//                                                                        //
////////////////////////////////////////////////////////////////////////////

#include <def21375.h>

#define	PCI			0x00080000
#define	OFFSET		0x00080000

.extern _samples, _outp_buf;

.section /dm seg_dmda;

.global TCB_Block_ADCx;
//Set up the TCBs to rotate automatically
.var TCB_Block_ADCx[4] = TCB_Block_ADCx + 3, 2, -1, _samples + 1 - OFFSET;
.var TCB_Block_DAC0[4] = TCB_Block_DAC0 + 3, 2, -1, _outp_buf + 1 - OFFSET;
.var TCB_Block_DAC1[4] = TCB_Block_DAC1 + 3, 2, -1, _outp_buf + 3 - OFFSET;
.var TCB_Block_DAC2[4] = TCB_Block_DAC2 + 3, 2, -1, _outp_buf + 5 - OFFSET;

.section/pm seg_pmco;

/////////////////////////////////////////////////////////////////////////////
//                                                                         //
//  Use:  SPORT1 Interrupt Service Routines                                //
//  	                                                                   //
// Here is the mapping between the SPORTS and the DACS                     //
// ADC -> DSP  : SPORT1A : I2S                                             //
// DSP -> DAC1 : SPORT2B : I2S, LSBF                                       //
// DSP -> DAC2 : SPORT3A : I2S, LSBF                                       //
// DSP -> DAC3 : SPORT3B : I2S, LSBF                                       //
//  	                                                                   //
/////////////////////////////////////////////////////////////////////////////

.global _initSPORT;
_initSPORT:
	//============================================================
	//
	// Make sure that the multichannel mode registers are cleared
	//
	//------------------------------------------------------------
	dm(SPMCTL0) = m5;
	dm(SPMCTL1) = m5;
	dm(SPMCTL2) = m5;
	dm(SPMCTL3) = m5;
	dm(SPCTL0) = m5;
	dm(SPCTL1) = m5;
	dm(SPCTL2) = m5;
	dm(SPCTL3) = m5;

	//============================================================
	//
	// Configure SPORT 1 as a receiver (input from ADC)
	//
	//    OPMODE = I2S mode
	//    SLEN24 = 24 bit of data in each 32-bit word
	//    SPEN_A = Enable data channel A
	//    Enable DMA Chaining
	//
	//------------------------------------------------------------

	r0 = OPMODE | SLEN24 | SPEN_A | SCHEN_A | SDEN_A;
	dm(SPCTL1) = r0;
	r0 = TCB_Block_ADCx - OFFSET + 3;
	dm(CPSP1A) = r0;

	//============================================================
	//
	// Configure SPORTs 2 & 3 as transmitter (output to DACs 1-3)
	//
	//    SPTRAN = Transmit on serial port
	//    OPMODE = I2S mode
	//    SLEN24 = 24 bit of data in each 32-bit word
	//    SPEN_A = Enable data channel A
	//    SPEN_B = Enable data channel B
	//    Enable DMA Chaining
	//------------------------------------------------------------

	r0 = SPTRAN|OPMODE |SLEN24|LSBF|SPEN_B|SCHEN_B|SDEN_B;
	dm(SPCTL2) = r0;

	r0 = SPTRAN|OPMODE |SLEN24|LSBF
		|SPEN_A|SCHEN_A|SDEN_A
		|SPEN_B|SCHEN_B|SDEN_B;
	dm(SPCTL3) = r0;

	r0 = TCB_Block_DAC0 - OFFSET + 3;
	dm(CPSP3B) = r0;

	r0 = TCB_Block_DAC1 - OFFSET + 3;
	dm(CPSP3A) = r0;

	r0 = TCB_Block_DAC2 - OFFSET + 3;
	dm(CPSP2B) = r0;

	bit set IMASK P3I;					// unmask SPORT1 interrupt
	rts(DB);
	dm(EMEP0) = m0;						// for DMA transfer
	dm(IMEP0) = m6;						// from Internal memory to SDRAM
_initSPORT.end:
