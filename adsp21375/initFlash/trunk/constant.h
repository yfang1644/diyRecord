//constant definition

#define FS		64453.125		// sampling frequency
// Total SDRAM 32bit*4M
#define	MSB			18			// MAXBUFFER = 2^18
#define	SDRAM_ADDR	0x200000
#define MAXBUFFER	(1<<MSB)	// 256K words for each in/out channel.(8x8)
								// max delay time = 262144/96 = 2730ms

#define	INS				2		// input channels
#define	OUTS			6		// output channels

#define	_array		0x200000	//
#define	_sineTable	(0x200000+10*MAXBUFFER)

// PEQ: parameter equalizer, each 2nd order IIR(for simplicity)
// 每节滤波器为2阶，包含4个参数。节增益参数另列
// 输入由 11 个 PEQ 构成
// 输出由 6阶HPF、6阶LPF、3个PEQ构成(3节+3节+3节)
#define IN_PEQS		11			// 11 PEQs:Direct I--> Direct II need add one
#define OUT_PEQS	9			// 6th order HPF, 6th order LPF and 3 bands PEQ


#define COMP_PEQS	1			// 1 Parameter equalizer
#define IN_GEQS		31			// 31 Bands graphic equalizer

//Peak Limiter time const definition: = 1 - expf( -1/(FS*time) ) = 1- expf( -1/(64.453125*time) )
#define LimiterFlatnessRise		1.0		//time -> 0
#define LimiterFlatnessFall		0.7		//time -> 50ms
#define LimiterAttackTime		1.0		//time ->0
#define LimiterReleaseTime		0.7		//time = 50ms

#define	_1MS					247500	// cycles per ms(@247.5MHz)
#define	LED_FLASH_RATE			40		//
#define	SWITCH_DELAY			10		//
#define	LEVEL_INDICATOR			10		//

#define Standard0dB				1.0
#define StandardN6dB			0.5
#define StandardN10dB	 		0.1
#define StandardN20dB	 		0.01
#define StandardN40dB	  		0.0001

#define	UART_BUF_SIZE	512

#define PI 3.1415926535897932384626
#define ROOT2	1.41421356237f
#define GEQQvalue	4.33f


