/************************************************************************
 *
 * lib_glob.h
 *
 * (c) Copyright 2001-2004 Analog Devices, Inc.  All rights reserved.
 * $Revision: 1.2 $
 ************************************************************************/

/* Back in the old days ... these were the different 	*/
/* versions that we supported.  Now, it is only one, so */
/* these are just defines.  Ahh for the good old days...*/

#define DMSTACK
#define RTRTS
#define REGPASS

/*  These symbols define the names of specific segments
    used by the runtime library. */

#define DMRAM
#define DMCONST
#define CSWAP

/*  This defines the precision of immediate data used 
    in the runtime library. */

#define MACHINE_PRECISION 40
#define MEMORY_PRECISION 32

#define dma_b B3
#define dma_i I3
#define dma_m M3
#define dma_l L3

#define dmb_b B2
#define dmb_i I2
#define dmb_m M2
#define dmb_l L2

#define dmc_b B5
#define dmc_i I5
#define dmc_m M5
#define dmc_l L5

#define dm_bse B4
#define dm_ptr I4
#define dm_mdf M4
#define dm_lnt L4

#define dm_0  M5
#define dm_1  M6
#define dm_M1 M7

#define pm_0  M13
#define pm_1  M14
#define pm_M1 M15

#define pma_b B11
#define pma_i I11
#define pma_m M11
#define pma_l L11

#define pmb_b B10
#define pmb_i I10
#define pmb_m M10
#define pmb_l L10

#define pmc_b B13
#define pmc_i I13
#define pmc_m M13
#define pmc_l L13

#define pm_bse B12
#define pm_ptr I12
#define pm_mdf M12
#define pm_lnt L12

/*  These symbols define the appropriate code for each compile
    time symbol. Note: CALLER_HOLD's parameter must be the same
    as SAVE_OLD_FRAME's parameter */

#ifdef CSWAP
#define HOLD_FRAME
#define SWAP_FRAME
#define CALLER_HOLD(a) a=frame_ptr;
#define CALLER_SWAP frame_ptr=stack_ptr;
#define SAVE_OLD_FRAME(a) DM(I7,M7)=a;
#define SAVE_RET_ADDR DM(I7,M7)=PC;
#define RESTORE_STACK stack_ptr=frame_ptr;
#define RESTORE_FRAME frame_ptr=frame_stk;
#endif

#ifdef RTRTS
#define FETCH_RETURN I12=DM(dm_M1, frame_ptr);
#define RTLCALL JUMP 
#define RETURN JUMP (M14,I12)
#endif

#ifdef DMSTACK
#define STACK_SPACE DMDATA
#define Stack_Space_Name seg_stak

#define frame_ptr I6
#define stack_ptr I7
#define frame_stk DM(0,I6)

#define stack_0  M5
#define stack_1  M6
#define stack_M1 M7

#define stack_breg B4
#define stack_ireg I4
#define stack_mreg M4
#define stack_lreg L4


#define puts            dm(i7, m7)
#define gets(x)         dm(x, i7)
#define alter(x)        modify(i7, x)

#ifdef REGPASS
#define reads(a,b) a=DM(b,I6)
#define readparam4(a) a=DM(1,I6)
#define readparam5(a) a=DM(2,I6)
#define readparam6(a) a=DM(3,I6)
#define readparam7(a) a=DM(4,I6)
#define readparam8(a) a=DM(5,I6)
#define readparam9(a) a=DM(6,I6)
#endif

/*  This routine access stack memory */
#define stackmem(i,m) DM(i,m)
#define stackvar(a) DM(a)
#endif

#ifdef DMCONST
#define SPACE DMDATA
#define Data_Space_Name seg_dmda

#define b_reg B4
#define i_reg I4
#define m_reg M4
#define l_reg L4

#define mem(i,m) DM(i,m)
#endif

#ifdef DMRAM
#define RAM_SPACE DMDATA
#define Ram_Space_Name seg_dmda

#define ram_breg B4
#define ram_ireg I4
#define ram_mreg M4
#define ram_lreg L4

#define ram_0  M5
#define ram_1  M6
#define ram_M1 M7

#define rammem(i,m) DM(i,m)
#define ramvar(a) DM(a)
#endif

#define DMDATA DM
#define PMDATA PM
#define CODE   PM

#define	DELAY(x)	lcntr=(x), do(pc,1) until lce; nop
