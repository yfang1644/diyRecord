//parameters declaration and initialization...
#include <stdio.h>
#include <math.h>
#define	FS	48000
#define	PI	3.1415926535897932
float FrequencyTable[121] = {
	 20.0,  21.2,  22.4,  23.7,  25.0,  26.5,  28.0,  29.7,  31.5,  33.5,
	 35.5,  37.5,  40.0,  42.5,  45.0,  47.4,  50.0,  53.0,  56.0,  59.5,
	 63.0,  67.0,  71.0,  75.0,  80.0,  85.0,  90.0,  95.0,   100,   106,
	  112,   118,   125,   132,   140,   150,   160,   170,   180,   190,
	  200,   212,   224,   237,   250,   265,   280,   297,   315,   335,
	  355,   375,   400,   425,   450,   474,   500,   530,   560,   595,
	  630,   670,   710,   750,   800,   850,   900,   950,  1000,  1060,
     1120,  1180,  1250,  1320,  1400,  1500,  1600,  1700,  1800,  1900,
	 2000,  2120,  2240,  2370,  2500,  2650,  2800,  2970,  3150,  3350,
	 3550,  3750,  4000,  4250,  4500,  4740,  5000,  5300,  5600,  5950,
	 6300,  6700,  7100,  7500,  8000,  8500,  9000,  9500, 10000, 10600,
	11200, 11800, 12500, 13200, 14000, 15000, 16000, 17000, 18000, 19000,
	20000};								// 1/12 oct.

float QTable[73] = {
	 0.31,  0.32,  0.34,  0.36,  0.39,  0.41,  0.43,  0.46,  0.49,  0.52,
	 0.55,  0.58,  0.61,  0.65,  0.69,  0.73,  0.77,  0.82,  0.87,  0.92,
	 0.97,  1.03,  1.09,  1.15,  1.22,  1.29,  1.37,  1.45,  1.54,  1.63,
	 1.73,  1.83,  1.94,  2.05,  2.17,  2.30,  2.44,  2.58,  2.73,  2.90,
	 3.07,  3.25,  3.44,  3.65,  3.86,  4.09,  4.33,  4.59,  4.86,  5.15,
	 5.46,  5.78,  6.12,  6.48,  6.87,  7.27,  7.71,  8.16,  8.65,  9.16,
	 9.70, 10.30, 10.90, 11.50, 12.20, 12.90, 13.70, 14.50, 15.40, 16.30,
	17.30, 18.30, 19.40};

//  ‰»Î≤Œ ˝æ˘∫‚∆˜‘§÷√ PEQParam: type, frequency[0,120], level, q=[0,72]
// level = -32dB -- 32dB, step 0.25dB, 0 = 0dB
// type:
//	0:Equalizer OFF
//	1:Peaking Equalizer

/*
	Function: caculating parameter equalizer's coeffs
	Import:	  Type,Freq,Level,Q in peqstruct
	type:
		0: Equalizer OFF
		1: Peaking Equalizer
		2: Bandpass filter
		3: High-Shelving Equalizer
		4: Low-Shelving Equalizer
		5: Notch Filter
		0x81 -- GEQ
	level = -32dB -- +32dB, step 0.25dB, 0 = 0dB
*/
float *coeff;
float *gain;
int peqstruct;

void calculatePEQ(void)
{
	int type, freq, level, q;
	float A,omega,sinw,cosw,alpha,beta;
	float b0,b1,b2,a0,a1,a2;

	type = (peqstruct >> 24);
	freq = (peqstruct >> 16) & 0xff;
	level = ((peqstruct >> 8) & 0xff) - 24;
	q = peqstruct & 0xff;

	printf("lev. %d, Q %f\n", level, QTable[q]);
	A = powf(10.0f, level/80.0);				// for Peaking&Shelving EQ only
	omega = 2*PI*FrequencyTable[freq]/FS;		// Freq:[0,120]
	sinw = sin(omega);
	cosw = cos(omega);
	alpha = sinw/(2*QTable[q]);					//Q:[0,72]
	beta = sqrtf(2*A);				//beta = sqrt[ (A^2 + 1)/S - (A-1)^2 ]
									//for shelf type only
									//S(shelf slope)=1 for this application

	b0 = 1; b1 = 0; b2 = 0;
	a0 = 1; a1 = 0; a2 = 0;
	switch(type)
	{
		case 1:						//Peaking Equalizer
			b0 = 1 + alpha * A;
			b1 = -2 * cosw;
			b2 = 1 - alpha * A;
			a0 = 1 + alpha / A;
			a1 = b1;
			a2 = 1 - alpha / A;
			break;

		case 2:						//Bandpass filter
			b0 = alpha;
			b1 = 0;
			b2 = -alpha;
			a0 = 1 + alpha;
			a1 = -2 * cosw;
			a2 = 1 - alpha;
			break;

		case 3:						//High-Shelving Equalizer
			b0 = A * ((A + 1) + (A - 1) * cosw + beta * sinw);
			b1 = -2 * A * ((A - 1) + (A + 1) * cosw);
			b2 = A * ((A + 1) + (A - 1) * cosw - beta * sinw);
			a0 = (A + 1) - (A - 1) * cosw + beta * sinw;
			a1 = 2 * ((A - 1) - (A + 1) * cosw);
			a2 = (A + 1) - (A - 1) * cosw - beta * sinw;
			break;

		case 4:						//Low-Shelving Equalizer
			b0 = A * ((A + 1) - (A - 1) * cosw + beta * sinw);
			b1 = 2 * A * ((A - 1) - (A + 1) * cosw);
			b2 = A * ((A + 1) - (A - 1) * cosw - beta * sinw);
			a0 = (A + 1) + (A - 1) * cosw + beta * sinw;
			a1 = -2 * ((A - 1) + (A + 1) * cosw);
			a2 = (A + 1) + (A - 1) * cosw - beta * sinw;
			break;

		case 5:						//Notch Filter
			b0 = 1;
			b1 = -2 * cosw;
			b2 = 1;
			a0 = 1 + alpha;
			a1 = b1;
			a2 = 1 - alpha;
			break;

		default:					// others(include 0), equalizer off
			break;
	}
	printf("b0, b1, b2 -- a0, a1, a2\n");
	printf("p1=[%4.8f %4.8f %4.8f]; q1=[%4.8f %4.8f %4.8f];\n",
			b0, b1, b2, a0, a1, a2);
}
/*
	Function: Calculate HPF/LPF coefficients, max. 6th order
	Import:	  type,Freq,type, freq in peqstruct
	type:
		0: direct
		1: Butterworth, 2nd order(-12dB/oct)
		2: Butterworth, 3rd order(-18dB/oct)
		3: Butterworth, 4th order(-24dB/oct)
		4: Butterworth, 5th order(-30dB/oct)
		5: Butterworth, 6th order(-36dB/oct)
		6: Bessel, 2nd order
		7: Bessel, 3nd order
		8: Bessel, 4th order
		9: Bessel, 5th order
		10:Bessel, 6th order
		11:Linkwitz-Riley, 2nd order
		12:Linkwitz-Riley, 4th order

*/

void calculateCrossover(int low_pass, int type, int freq)
{
float coeff_temp1[5];	//temp for exchanging..
float coeff_temp2[5];	//temp for exchanging..
float coeff_temp3[5];	//temp for exchanging..
	// low_pass = 1 for low pass filter, low_pass = -1 for high pass filter
	float wc, wo, rk, temp, pk;

	//Direct refresh coeff_temp[], a0 = 1
	coeff_temp1[0] = 0;//b2
	coeff_temp1[1] = 0;//b1
	coeff_temp1[2] = 1;//b0
	coeff_temp1[3] = 0;//a2
	coeff_temp1[4] = 0;//a1
	
	coeff_temp2[0] = 0;//b2
	coeff_temp2[1] = 0;//b1
	coeff_temp2[2] = 1;//b0
	coeff_temp2[3] = 0;//a2
	coeff_temp2[4] = 0;//a1
	
	coeff_temp3[0] = 0;//b2
	coeff_temp3[1] = 0;//b1
	coeff_temp3[2] = 1;//b0
	coeff_temp3[3] = 0;//a2
	coeff_temp3[4] = 0;//a1
	
	wc = tan(PI*freq/FS);
	switch (type)
	{
		case 1:	//Butterworth, 2nd order(-12dB/oct)
			wo = 1.0;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 1.414213562373095;		// 2 * sin(PI/4);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1
			break;

		case 2:	//Butterworth, 3rd order(-18dB/oct)
			wo = 1.0;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 1.0;				// 2 * sin(PI/6);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			temp = 1.0 / (rk + 1.0);
			coeff_temp3[2] = rk * temp;							//b0
			coeff_temp3[1] = low_pass * coeff_temp3[2];			//b1
			coeff_temp3[4] = low_pass * (rk - 1.0) * temp;		//a1
			break;

		case 3:	//Butterworth, 4th order(-24dB/oct)
			wo = 1.0;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 0.76536686473018;			// 2 * sin(PI/8);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			pk = 1.84775906502257351;		// 2 * sin(3*PI/8);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp2[0] = rk * rk * temp;					//b2
			coeff_temp2[1] = 2.0 * low_pass * coeff_temp2[0];	//b1
			coeff_temp2[2] = coeff_temp2[0];					//b0
			coeff_temp2[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp2[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1
			break;

		case 4:	//Butterworth, 5th order(-30dB/oct)
			wo = 1.0;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 0.6180339887498948482;		//2 * sin(PI/10);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			pk = 1.6180339887498948482;		// 2 * sin(3*PI/10);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp2[0] = rk * rk * temp;					//b2
			coeff_temp2[1] = 2.0 * low_pass * coeff_temp2[0];	//b1
			coeff_temp2[2] = coeff_temp2[0];					//b0
			coeff_temp2[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp2[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			temp = 1.0 / (rk + 1.0);
			coeff_temp3[2] = rk * temp;							//b0
			coeff_temp3[1] = low_pass * coeff_temp3[2];			//b1
			coeff_temp3[4] = low_pass * (rk - 1.0) * temp;		//a1
			break;

		case 5:	//Butterworth, 6th order(-36dB/oct)
			wo = 1.0;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 0.517638090205;			// 2 * sin(PI/12);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			pk = 1.414213562373095;			// 2 * sin(3*PI/12);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp2[0] = rk * rk * temp;					//b2
			coeff_temp2[1] = 2.0 * low_pass * coeff_temp2[0];	//b1
			coeff_temp2[2] = coeff_temp2[0];					//b0
			coeff_temp2[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp2[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			pk = 1.9318516525781365735;		// 2 * sin(5*PI/12);
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp3[0] = rk * rk * temp;					//b2
			coeff_temp3[1] = 2.0 * low_pass * coeff_temp3[0];	//b1
			coeff_temp3[2] = coeff_temp3[0];					//b0
			coeff_temp3[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp3[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1
			break;

		case 6:	//Bessel, 2nd order(-12dB/oct)
			wo = 1.732050808;
			wo = 1.272019649514069;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 3.0 / wo;
			pk = 1.732050807568877;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1
			break;

		case 7:	//Bessel, 3rd order(-18dB/oct)
			wo = 2.541541401;
			wo = 1.447617133148852;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 3.6778146454 / wo;
			pk = 1.447080359898814;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			wo = 2.3221853546;
			wo = 1.322675799895588;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			temp = 1.0 / (rk + 1.0);
			coeff_temp3[2] = rk * temp;							//b0
			coeff_temp3[1] = low_pass * coeff_temp3[2];			//b1
			coeff_temp3[4] = low_pass * (rk - 1.0) * temp;		//a1
			break;

		case 8:	//Bessel, 4th order(-24dB/oct)
			wo = 3.389365793;
			wo = 1.603357516232937;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 4.2075787944 / wo;
			pk = 1.241405930098654;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			wo = 3.023264939;
			wo = 1.430171559972244;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 5.7924212056 / wo;
			pk = 1.915948923733869;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp2[0] = rk * rk * temp;					//b2
			coeff_temp2[1] = 2.0 * low_pass * coeff_temp2[0];	//b1
			coeff_temp2[2] = coeff_temp2[0];					//b0
			coeff_temp2[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp2[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			break;

		case 9:	//Bessel, 5th order(-30dB/oct)
			wo = 4.261022801;
			wo = 1.755377776624902;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 4.6493486064 / wo;
			pk = 1.091134411433174;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			wo = 3.777893661;
			wo = 1.556347122314373;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			pk = 6.7039127984 / wo;
			pk = 1.774510719467443;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp2[0] = rk * rk * temp;					//b2
			coeff_temp2[1] = 2.0 * low_pass * coeff_temp2[0];	//b1
			coeff_temp2[2] = coeff_temp2[0];					//b0
			coeff_temp2[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp2[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			wo = 3.6467385953;
			wo = 1.502316271435266;
			if(1 == low_pass)	rk = wo * wc;
			else	rk = wo / wc;
			temp = 1.0 / (rk + 1.0);
			coeff_temp3[2] = rk * temp;							//b0
			coeff_temp3[1] = low_pass * coeff_temp3[2];			//b1
			coeff_temp3[4] = low_pass * (rk - 1.0) * temp;		//a1
			break;

		case 10:	//Bessel, 6th order(-36dB/oct)
			wo = 5.149177152;
			wo = 1.904707612314687;
			if(1 == low_pass)	rk = wo * wc;
			else	rk =  wo / wc;
			pk = 5.0318644956 / wo;
			pk = 0.9772172032345484;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			wo = 4.566489152;
			wo = 1.689168267600359;
			if(1 == low_pass)	rk = wo * wc;
			else	rk =  wo / wc;
			pk = 7.4714167126 / wo;
			pk = 1.636140252089971;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp2[0] = rk * rk * temp;					//b2
			coeff_temp2[1] = 2.0 * low_pass * coeff_temp2[0];	//b1
			coeff_temp2[2] = coeff_temp2[0];					//b0
			coeff_temp2[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp2[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			wo = 4.336027051;
			wo = 1.603919128779323;
			if(1 == low_pass)	rk = wo * wc;
			else	rk =  wo / wc;
			pk = 8.4967187918 / wo;
			pk = 1.959563141846909;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp3[0] = rk * rk * temp;					//b2
			coeff_temp3[1] = 2.0 * low_pass * coeff_temp3[0];	//b1
			coeff_temp3[2] = coeff_temp3[0];					//b0
			coeff_temp3[3] = (rk * (rk - pk) + 1.0) * temp;		//a2
			coeff_temp3[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1
			break;

		case 11://Linkwitz-Riley, 2nd order(-12dB/oct)
			wo = 1.0;
			if(1 == low_pass)	rk = wc / wo;
			else	rk = wo / wc;
			pk = 2.0;
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1
			break;

		case 12://Linkwitz-Riley, 4th order(-24dB/oct)
			wo = 1;
			if(1 == low_pass)	rk = wc / wo;
			else	rk = wo / wc;
			pk = 1.414213562373095;								//2*sin(PI/4)
			temp = 1.0 / (rk * (rk + pk) + 1.0);
			coeff_temp1[0] = rk * rk * temp;					//b2
			coeff_temp1[1] = 2.0 * low_pass * coeff_temp1[0];	//b1
			coeff_temp1[2] = coeff_temp1[0];					//b0
			coeff_temp1[3] = (rk * (rk - pk) + 1) * temp;		//a2
			coeff_temp1[4] = 2.0 * low_pass * (rk * rk - 1) * temp;//a1

			coeff_temp2[0] = coeff_temp1[0];
			coeff_temp2[1] = coeff_temp1[1];
			coeff_temp2[2] = coeff_temp1[2];
			coeff_temp2[3] = coeff_temp1[3];
			coeff_temp2[4] = coeff_temp1[4];
			break;

		default:
			break;
	}

	printf("b0, b1, b2 -- a0, a1, a2\n");
	printf("p1=[%4.8f %4.8f %4.8f]; q1=[1.0 %4.8f %4.8f];\n",
			coeff_temp1[2], coeff_temp1[1], coeff_temp1[0],
			coeff_temp1[4], coeff_temp1[3]);
	printf("p2=[%4.8f %4.8f %4.8f]; q2=[1.0 %4.8f %4.8f];\n",
			coeff_temp2[2], coeff_temp2[1], coeff_temp2[0],
			coeff_temp2[4], coeff_temp2[3]);
	printf("p3=[%4.8f %4.8f %4.8f]; q3=[1.0 %4.8f %4.8f];\n",
			coeff_temp3[2], coeff_temp3[1], coeff_temp3[0],
			coeff_temp3[4], coeff_temp3[3]);
}

main(int argc, char *argv[])
{
	int low_pass, type, freq;
//	low_pass = atoi(argv[1]);
//	type = atoi(argv[2]);
//	freq = atoi(argv[3]);
//	peqstruct = 0x0344202e;
	peqstruct = 0x01443000;
	calculatePEQ();
	peqstruct = 0x0444002e;
	calculatePEQ();

	calculateCrossover(1, 10, 5000);
}

/* scilab ≤‚ ‘
//crossover
p1 = [1.00000000 0.00000000 0.00000000]; q1=[1.00000000 0.00000000 0.00000000];
p2 = [0.06151177 0.06151177 0.00000000]; q2=[1.00000000 -0.87697649 0.00000000];
p3 = [0.00401551 0.00803101 0.00401551]; q3=[1.00000000 -1.86140847 0.87747049];


z=poly(0, 'z');
r = [z^2 z 1]';
hz =( p1*r)/(q1*r)*(p2*r)/(q2*r)*(p3*r)/(q3*r);

[hzm,fr]=frmag(hz,256);
plot2d(fr',hzm');

//PEQ
p1=[1.99996018 -4.00000000 2.00003982]; q1=[1.99996018 -4.00000000 2.00003982];
p1=[1.03007317 -1.98288977 0.96992677]; q1=[1.00755405 -1.98288977 0.99244595];
*/

