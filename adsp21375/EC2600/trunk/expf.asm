/*
	This subroutine computes the exponential value of its floating point input.
		f0 = exp(f4);
		// ignore bigX and smallX
		// FANGYUAN
	float exp(float x);		<Prototype>
*/
#include "lib_glob.h"

.extern ___float_divide;

.section/pm	seg_pmco;

.global _expf;

_expf:		i4 = exponential_data;			/*Skip one cycle after this*/
			f12 = abs f4, f1 = dm(i4, m6);	/*Fetch minimum input*/
			comp(f12, f1), f1 = dm(i4, m6);	/*Check for output 1*/
			if LT jump (pc, output_one);	/*Simply return 1*/
			f12 = f4 * f1, f8 = f4;			/*Compute N = X/ln(C)*/
			r4 = trunc f12;					/*Round to nearest*/
			f7 = FLOAT r4, f0 = dm(i4, m6);	/*Back to floating point*/

compute_g:	f12 = f0 * f7, f0 = dm(i4, m6);	/*Compute XN*C1*/
			f1 = f0 * f7, f12 = f8 - f12, f0 = dm(i4, m6);
											/*Compute |X|-XN*C1, and XN*C2*/
			f8 = f12 - f1;					/*Compute g=(|X|-XN*C1)-XN*C2*/

compute_R:	f1 = f8 * f8;			        /*Compute z=g*g*/
			f7 = f1 * f0, f0 = dm(i4, m6);	/*Compute p1*z*/
			f7 = f7 + f0, f0 = dm(i4, m6);	/*Compute p1*z + p0*/
			f7 = f8 * f7;					/*Compute g*P(z) = (p1*z+p0)*g*/
			f12 = f0 * f1, f0 = dm(i4, m6);	/*Compute q2*z*/
			f12 = f0 + f12, f8 = dm(i4, m6);	/*Compute q2*z + q1*/
			f12 = f1 * f12;					/*Compute (q2*z+q1)*z)*/
			call (pc, ___float_divide)(DB);
			f12 = f8 + f12;					/*Compute Q(z)=(q2*z+q1)*z+q0*/
			f12 = f12 - f7;					/*Compute Q(z) - g*P(z)*/

			f7 = f7 + f8;					/*R(g)=.5+(g*P(z))/(Q(z)-g*P(z))*/
			r4 = r4 + 1;					/*Get N+1 in fixed point*/
			f0=SCALB f7 by r4;				/*R(g) * 2^(N+1)*/
			EXIT;
output_one:
			f0 = 1.0;
			EXIT;

_expf.end:

.section/dm	seg_dmda;

.var exponential_data[9] =
				  0.000000001,				/*eps*/
				  1.4426950408889634074,	/*1/ln(2.0)*/
				  0.693359375,				/*C1*/
				 -2.1219444005469058277E-4, /*C2*/
				  0.59504254977591E-2,		/*P1*/
				  0.24999999999992,			/*P0*/
				  0.29729363682238E-3,		/*Q2*/
				  0.53567517645222E-1,		/*Q1*/
				  0.5;						/*Q0 and others*/
