#include <math.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/soundcard.h>

#define	PI	3.14159265359
#define	FS	48000
/*
	Function: Calculate HPF/LPF coefficients, max. 6th order
	Import:	  type,Freq,type, freq in High Pass Filter/Low Pass Filter
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
#define	IIR_SECOND_ORDER(param)	\
	if(1 == low_pass)	rk = wo * wc;		\
	else	rk = wo / wc;					\
	temp = 1.0 / (rk * (rk + pk) + 1.0);	\
	param[0] = rk * rk * temp;				/*b2*/\
	param[1] = 2.0 * low_pass * param[0];	/*b1*/\
	param[2] = param[0];					/*b0*/\
	param[3] = (rk * (rk - pk) + 1.0) * temp;	/*a2*/\
	param[4] = 2.0 * low_pass * (rk * rk - 1) * temp;/*a1*/

#define	IIR_FIRST_ORDER(param)	\
	if(1 == low_pass)	rk = wo * wc;			\
	else	rk = wo / wc;						\
	temp = 1.0 / (rk + 1.0);					\
	param[2] = rk * temp;					/*b0*/\
	param[1] = low_pass * param[2];			/*b1*/\
	param[4] = low_pass * (rk - 1.0) * temp;/*a1*/

float coeff[3][5];

void filter_design(int low_pass, int freq, int type)
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

	wc = tan(PI * freq / FS);
	switch (type)
	{
		case 1:	//Butterworth, 2nd order(-12dB/oct)
			wo = 1.0;
			pk = 1.414213562373095;		// 2 * sin(PI/4);
			IIR_SECOND_ORDER(coeff_temp1);
			break;

		case 2:	//Butterworth, 3rd order(-18dB/oct)
			wo = 1.0;
			pk = 1.0;				// 2 * sin(PI/6);
			IIR_SECOND_ORDER(coeff_temp1);

			IIR_FIRST_ORDER(coeff_temp3);
			break;

		case 3:	//Butterworth, 4th order(-24dB/oct)
			wo = 1.0;
			pk = 0.76536686473018;			// 2 * sin(PI/8);
			IIR_SECOND_ORDER(coeff_temp1);

			pk = 1.84775906502257351;		// 2 * sin(3*PI/8);
			IIR_SECOND_ORDER(coeff_temp2);
			break;

		case 4:	//Butterworth, 5th order(-30dB/oct)
			wo = 1.0;
			pk = 0.6180339887498948482;		//2 * sin(PI/10);
			IIR_SECOND_ORDER(coeff_temp1);

			pk = 1.6180339887498948482;		// 2 * sin(3*PI/10);
			IIR_SECOND_ORDER(coeff_temp2);

			IIR_FIRST_ORDER(coeff_temp3);
			break;

		case 5:	//Butterworth, 6th order(-36dB/oct)
			wo = 1.0;
			pk = 0.517638090205;			// 2 * sin(PI/12);
			IIR_SECOND_ORDER(coeff_temp1);

			pk = 1.414213562373095;			// 2 * sin(3*PI/12);
			IIR_SECOND_ORDER(coeff_temp2);

			pk = 1.9318516525781365735;		// 2 * sin(5*PI/12);
			IIR_SECOND_ORDER(coeff_temp3);
			break;

		case 6:	//Bessel, 2nd order(-12dB/oct)
			wo = 1.732050808;
			pk = 3.0 / wo;
			IIR_SECOND_ORDER(coeff_temp1);
			break;

		case 7:	//Bessel, 3rd order(-18dB/oct)
			wo = 2.541541401;
			pk = 3.6778146454 / wo;
			IIR_SECOND_ORDER(coeff_temp1);

			wo = 2.3221853546;
			IIR_FIRST_ORDER(coeff_temp3);
			break;

		case 8:	//Bessel, 4th order(-24dB/oct)
			wo = 3.389365793;
			pk = 4.2075787944 / wo;
			IIR_SECOND_ORDER(coeff_temp1);

			wo = 3.023264939;
			pk = 5.7924212056 / wo;
			IIR_SECOND_ORDER(coeff_temp2);
			break;

		case 9:	//Bessel, 5th order(-30dB/oct)
			wo = 4.261022801;
			pk = 4.6493486064 / wo;
			IIR_SECOND_ORDER(coeff_temp1);

			wo = 3.777893661;
			pk = 6.7039127984 / wo;
			IIR_SECOND_ORDER(coeff_temp2);

			wo = 3.6467385953;
			IIR_FIRST_ORDER(coeff_temp3);
			break;

		case 10:	//Bessel, 6th order(-36dB/oct)
			wo = 5.149177152;
			pk = 5.0318644956 / wo;
			IIR_SECOND_ORDER(coeff_temp1);

			wo = 4.566489152;
			pk = 7.4714167126 / wo;
			IIR_SECOND_ORDER(coeff_temp2);

			wo = 4.336027051;
			pk = 8.4967187918 / wo;
			IIR_SECOND_ORDER(coeff_temp3);
			break;

		case 11://Linkwitz-Riley, 2nd order(-12dB/oct)
			wo = 1.0;
			pk = 2.0;
			IIR_SECOND_ORDER(coeff_temp1);
			break;

		case 12://Linkwitz-Riley, 4th order(-24dB/oct)
			wo = 1;
			pk = 1.414213562373095;						//2*sin(PI/4)
			IIR_SECOND_ORDER(coeff_temp1);

			IIR_SECOND_ORDER(coeff_temp2);
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

	coeff[0][0] = coeff_temp1[0];
	coeff[0][1] = coeff_temp1[1];
	coeff[0][2] = coeff_temp1[2];
	coeff[0][3] = coeff_temp1[3];
	coeff[0][4] = coeff_temp1[4];
	
	coeff[1][0] = coeff_temp2[0];
	coeff[1][1] = coeff_temp2[1];
	coeff[1][2] = coeff_temp2[2];
	coeff[1][3] = coeff_temp2[3];
	coeff[1][4] = coeff_temp2[4];
	
	coeff[2][0] = coeff_temp3[0];
	coeff[2][1] = coeff_temp3[1];
	coeff[2][2] = coeff_temp3[2];
	coeff[2][3] = coeff_temp3[3];
	coeff[2][4] = coeff_temp3[4];
/*
  y(n) = coeff2*x(n)+coeff1*x(n-1)+coeff0*x(n-2)-coeff4*y(n-1)-coeff3*y(n-2)
*/

}

/*****************************************************************************/
/* DESCRIPTION                                                               */
/*   Infinite Impulse Response (IIR) filters fourth order type I and type II */
/*   Takes 3 numerator coefficients and 3 denominator coefficients.          */
/*                                                                           */
/*---------------------------------------------------------------------------*/
/*                                                                           */
/* An second infinite impulse response (IIR) filter can be represented by    */
/* the following equation:                                                   */
/*                                                                           */
/*        b0 + b1.z^-1 + b2.z^-2                                             */
/* H(z) = ----------------------                                             */
/*        a0 + a1.z^-1 + a2.z^-2                                             */
/*                                                                           */
/* where H(z) is the transfer function. a0 is always 1.000                   */
/*                                                                           */
/* To implement a fourth order filter, two of these stages are cascaded.     */
/*                                                                           */
/*****************************************************************************/

/* Numerator coefficients */
#define B0 2
#define B1 1
#define B2 0

/* Denominator coefficients */
#define A0 0
#define A1 4
#define A2 3

/*****************************************************************************/
/* IIR_direct_form_I()                                                       */
/*---------------------------------------------------------------------------*/
/*                                                                           */
/* Sixth order direct form I IIR filter implemented by cascading 3 second    */
/* order filters.                                                            */
/*                                                                           */
/* This implementation uses two buffers, one for x[n] and the other for y[n] */
/*                                                                           */
/*****************************************************************************/

static float x[3][3] = {0, 0, 0, 0, 0, 0, 0, 0, 0 };
static float y[3][3] = {0, 0, 0, 0, 0, 0, 0, 0, 0 };
short IIR_direct_form_I(short input)
{
	float temp;
	/* x(n), x(n-1), x(n-2), y(n), y(n-1), y(n-2). Must be static */
	unsigned int stages;

	temp = (float) input; /* Copy input to temp */

	for ( stages = 0 ; stages < 3 ; stages++)
	{
		x[stages][0] = temp;			/* Copy input to x[stages][0] */

		temp  = coeff[stages][B0] * x[stages][0];	/* B0 * x(n)   */
		temp += coeff[stages][B1] * x[stages][1];	/* B1 * x(n-1) */
		temp += coeff[stages][B2] * x[stages][2];	/* B2 * x(n-2) */
		temp -= coeff[stages][A1] * y[stages][1];	/* A1 * y(n-1) */
		temp -= coeff[stages][A2] * y[stages][2];	/* A2 * y(n-2) */

		y[stages][0] = temp;

		/* Shuffle values along one place for next time */

		y[stages][2] = y[stages][1];   /* y(n-2) = y(n-1) */
		y[stages][1] = y[stages][0];   /* y(n-1) = y(n)   */

		x[stages][2] = x[stages][1];   /* x(n-2) = x(n-1) */
		x[stages][1] = x[stages][0];   /* x(n-1) = x(n)   */

		/* temp is used as input next time through */
	}

	return (short)temp;
}


int	fd = -1;
short *buf_out, *buf_in, *buf;

void audio_init()
{
	int i;
	int format = AFMT_S16_NE;
	int channels = 1;
	int speed = FS;
	int fragment = (0<<16)|(10);

	fd = open("/dev/dsp",O_RDWR);
	i = 0;
//	ioctl(fd, SNDCTL_DSP_BLOCK, &i);
//	ioctl(fd, SNDCTL_DSP_SETFRAGMENT, &fragment);
	ioctl(fd, SNDCTL_DSP_SPEED,&speed);
	ioctl(fd, SNDCTL_DSP_CHANNELS,&channels);
	ioctl(fd, SNDCTL_DSP_SETFMT,&format);

	buf_out = (short *)malloc(512 * 2);
	buf_in = (short *)malloc(512 * 2);
	buf = (short *)malloc(512 * 2);
}

int fc;

void * thread(void *p)
{
	int i, j;
	for(;;)
	{
		scanf("%d", &fc);
		filter_design(1, fc, 5);
		for(i = 0; i < 3; i++)
			for(j = 0; j < 3; j++)
				x[i][j] = y[i][j] = 0.0;
		fprintf(stderr, "filter updated fc=%d\n", fc);
	}
}

int main(int argc, char *argv[])
{
	float x;
	int i;
	int cnt = 0;
	int fc_temp;
	pthread_t pth_id;

	fc = fc_temp = 4000;
	pthread_create(&pth_id, NULL, thread, NULL);

	audio_init();
	for(;;)
	{
//		printf("%d\n", cnt++);
		read(fd, buf_in, 512);
		for(i = 0; i < 256; i++)
		{
			buf[i] = IIR_direct_form_I(buf_in[i]);
//			buf[i] = buf_in[i];
		}
		for(i = 0; i < 256; i++)	buf_out[i] = buf[i];
		write(fd, buf_out, 512);
	}
}	

