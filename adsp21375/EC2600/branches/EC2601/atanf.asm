/*
        This C language subroutine computes the arctangent
        of its floating point input.

        The Run Time Library for the C Language.

        #include <math.h>               <Header>
        float atanf(float x);           <Prototype>
        float atan2f(float y, float x); <Prototype>
		f8 = x, f4 = y;

        CycleCounts (21161):
                       MIN      MAX      Average    
        atan2f          29      112           83


        (c) Copyright 2003 Analog Devices, Inc.  All rights reserved.
        $Revision: 1.7 $
*/
#include "constant.h"
#include "lib_glob.h"

.segment /pm seg_pmco;

.global     _atan2f;

.extern    ___float_divide;

_atan2f:        R1=R1-R1, puts = R7;   /* Set R1 = 0                     */

                I4=atanf_data;         /* I4 = pointer to const data     */
                F7=PASS F4, R0=M6;     /* Set flag R0=1 (=atan2 branch)  */
                                       /* Set F2 = 1.0                   */
                F2=FLOAT R0, puts = R3;
                F3=PASS F8;                     

                IF NE JUMP (PC, overflow_tst) (DB); 
                                       /* Test for overflow if Y != 0.0  */
                  R7=124;              /* Max exponent - 3               */
                  F4=PASS F4, F12=F4;

                IF EQ JUMP (PC, restore_state);
                                       /* Exit if X = Y = 0.0, F12 = 0.0 */

overflow:       JUMP (PC, tst_sign_x) (DB);
                                       /* Handle Division by 0 (=>X/0)   */
                  F12=PI/2;            /* Load pi_over_2                 */
                  F4=PASS F4;     

overflow_tst:
                IF NE R1=LOGB F4;      /* Get exponent of X              */
                R0=LOGB F8;            /* Get exponent of Y              */
                R1=R1-R0;              /* Compute result exponent        */
                COMP(R1,R7);
                IF GE JUMP (PC, overflow);
                                       /* Quotient will overflow         */
                R7=-R7;
                COMP(R1,R7), R12=M5;   /* Set R12=0                      */
                IF LE JUMP (PC, tst_sign_y );
                                       /* Quotient will underflow        */

                CALL (PC, ___float_divide) (DB);
                  R1=R1-R1;            /* Set N=0                        */
                  F12=PASS F8, F7=F4;  /* Set Nu=X, De=Y, compute divide */

get_f:          F7=ABS F7, F8=dm(I4,m6);
                                       /* F7 = |X| or |X/Y|              */
                                       /* F8 = two_minus_sqrt_3          */
                R0=2;
                COMP(F7,F2), F12=F7;
                                       /* If F7 <= 1.0, skip divide      */      
                IF GT CALL (PC, ___float_divide) (DB);
                  IF GT R1=PASS R0, F7=F2;                
                                       /* Set N=2                        */
                  R2=R0+1;             /* Set Nu=1, De=f, compute divide */

tst_f:          COMP(F7,F8), M4=R2;
                                       /* If f <= two_minus_sqrt_3, jump */
                                       /* Set M4=3                       */
                IF LE JUMP (PC, tst_for_eps) (DB);                          
                  IF LE MODIFY(I4,M4);
                                       /* Adjust data pointer by M4      */
                  IF GT R1=R1+1;       /* N=N+1                          */
                                   
                F8=dm(I4,m6);          /* F8=sqrt_3_minus_1              */
                F12=F8*F7, F8=dm(I4,m6);
                                       /* F12=A*f,   F8=0.5              */
                F12=F12-F8;            /* F12=(A*f-1.0)                  */

                CALL (PC, ___float_divide) (DB);
                  F2=F12+F7, F8=dm(I4,m6);
                                       /* F2=((A*F-1.0)+f)               */
                                       /* F8=sqrt_3                      */
                  F12=F8+F7, F7=F2;    /* F12=sqrt_3+f                   */

tst_for_eps:    F8=ABS F7, F12=dm(I4,m6);
                COMP(F8,F12), R8=M6;   /* Test for small input: F8 < eps */
                                       /* R8=1                           */
                IF LE MODIFY(I4,M4);   /* Adjust data pointer by M4; only*/
                                       /* need to move pointer by 3 since*/
                                       /* last read without increment.   */

                IF LE JUMP (PC, tst_N), ELSE F0=PASS F7;

                F8=F0*F0, F2=dm(I4,m6);  
                                       /* g = f*f,              F2=p1    */
                F7=F8*F2, F2=dm(I4,m6); 
                                       /* P(g) = p1*g,          F2=p0    */
                F7=F7+F2;              /* P(g) = p1*g + p0               */

                F7=F7*F8, F2=dm(I4,m6);
                                       /* g*P(g) = (p1*g+p0)*g, F2=q1    */

                F12=F8+F2, F2=dm(I4,m5);
                                       /* Q(g) = (g+q1)                  */        
                                       /* F2=q0, don't move data pointer */

                CALL (PC, ___float_divide) (DB); 
                  F12=F12*F8, F8=F0;   /* Q(g) = (g+q1)*g,      F8=f     */
                  F12=F12+F2;          /* Q(g) = (g+q1)*g+q0             */

                F7=F7*F8;              /* f*R                            */
                F7=F7+F8, R8=M6;     /* f+f*R,                R8=1     */

tst_N:          COMP(R1,R8), F0=F7;
                IF GT F0=-F0;          /* If N>1 negate result           */

                R1=PASS R1, M4=R1; /* M4 = R1                        */
                IF EQ JUMP (PC, tst_sign_y), F12=PASS F0;
                                       /* Zero Result                    */
                F12=dm(M4,I4); /* If R1=1, load pi_over_6        */
                                       /* If R1=2, load pi_over_2        */
                                       /* If R1=3, load pi_over_3        */ 
                F12=F12+F0;
 
tst_sign_y:     F0=PI;                 /* Load pi                        */
                F3=PASS F3;          
                IF LT F12=F0-F12;      /* Result = pi - result, if Y < 0 */
 
                F4=PASS F4;
tst_sign_x:     IF LT F12=-F12;

restore_state:  F0=PASS F12, R3 = gets(1);
                R7 = gets(2);
				alter(2);
				EXIT;

._atan2f.end:


.segment/dm seg_dmda;

.var atanf_data[12] =    0.26794919243112270647,  /* two_minus_sqrt_3    */
                         0.73205080756887729353,  /* sqrt_3_minus_1      */
                         1.00000000000000000000,
                         1.73205080756887729353,  /* sqrt_3              */
                         0.000244140625,          /* eps                 */
                        -0.720026848898E+0,       /* p1                  */
                        -0.144008344874E+1,       /* p0                  */
                         0.475222584599E+1,       /* q1                  */
                         0.432025038919E+1,       /* q0                  */
                         PI/6,
                         PI/2,
                         PI/3;

