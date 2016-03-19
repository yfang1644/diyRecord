//constant definition

#define FS		64453.125		// sampling frequency
// Total SDRAM 32bit*4M
#define	MSB			18			// MAXBUFFER = 2^18
#define	SDRAM_ADDR	0x200000
#define MAXBUFFER	(1<<MSB)	// 256K words for each in/out channel.(8x8)
								// max delay time = 262144/96 = 2730ms

#define	INS				2		// input channels
#define	OUTS			6		// output channels

#define	_array_in1	SDRAM_ADDR	//
#define	_array_in2	(_array_in1 + MAXBUFFER)
#define	_array_out0	(_array_in1 + INS * MAXBUFFER)

#define	_sineTable	(_array_in1+(INS+OUTS+0)*MAXBUFFER)
#define	_noiseTable	(_array_in1+(INS+OUTS+1)*MAXBUFFER)

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

#define	_1MS					198000	// cycles per ms(@66MHz)
#define	LED_FLASH_RATE			25		// 闪烁速度
#define	SWITCH_DELAY			20		// 按键延迟
#define	LEVEL_INDICATOR			4		//

#define Standard0dB				0.8
#define StandardN6dB			0.2
#define StandardN10dB	 		0.08
#define StandardN20dB	 		0.008
#define StandardN40dB	  		0.00008

#define	UART_BUF_SIZE			1040

#define PI 3.1415926535897932384626

// define key codes
// 0 -- 7 (In0, In1, Out0, Out1 ... Out5)
// 8 -- ENTER
// 9 -- DISPLAY
// 10, 11 -- UP, DOWN
#define	KEY_IN0		0
#define	KEY_IN1		1
#define	KEY_OUT0	2
#define	KEY_OUT1	3
#define	KEY_OUT2	4
#define	KEY_OUT3	5
#define	KEY_OUT4	6
#define	KEY_OUT5	7
#define	KEY_ENTER	8
#define	KEY_DISPLAY	9
#define	KEY_UP		10
#define	KEY_DOWN	11
