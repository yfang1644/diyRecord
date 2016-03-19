///////////////////////////////////////////////////////////////////////////
//NAME:     main.asm                                                     //
//DATE:     2010-09-05                                                   //
//PURPOSE:  EC2600 ver. 2 on ADSP-21375                                  //
///////////////////////////////////////////////////////////////////////////

#include <def21375.h>
#include "constant.h"
#include "lib_glob.h"
#include "flash.h"

#define RESERVED_INTERRUPT	jump(pc, 0);jump(pc, 0);jump(pc, 0);jump(pc, 0);

.extern _initPLL;
.extern _initSDRAM;
.extern _initSRU;
.extern _initPanel;
.extern _remoteID;

.extern _writeFlash, _chipErase, _sectorErase;

.extern _remoteID, _Company, _DeviceInfo, _SoftwareVersion, _panelStatus;
.extern _programNo, _tempUserData;

.extern _updatePanel, _panelCommandTable, _digitBlackTable;

.section/pm		seg_rth;				// Runtime header segment
___EMUI:		RESERVED_INTERRUPT;		// 0x00: Emulator interrupt (highest priority, read-only, non-maskable)

___RSTI:	nop;
			jump _main;
			jump _main;
			jump _main;
___IICDI:	RESERVED_INTERRUPT;		// Access to illegal IOP space
___SOVFI:	RESERVED_INTERRUPT;		// status/loop/PC stack overflow
___TMZHI:	RESERVED_INTERRUPT; 	// high priority timer
/*
___FLTOI:	RESERVED_INTERRUPT;			// floating point overflow
___FLTUI:	RESERVED_INTERRUPT;			// floating point underflow
___FLTII:	RESERVED_INTERRUPT;			// floating point invalid
___EMULI:	RESERVED_INTERRUPT;			// Emulator low priority interrupt
___SFT0I:	RESERVED_INTERRUPT;			// user interrupts 0..3
___SFT1I:	RESERVED_INTERRUPT;
___SFT2I:	RESERVED_INTERRUPT;
___SFT3I:	RESERVED_INTERRUPT;
*/

.section /pm seg_pmco;

_main:
		call _systemInit;
		call _initPLL;			// Initializes PLL(core clock CCLK 33MHz*8)
		call _initSDRAM;		// Initializes SDRAM (SDCLK clock 2.5)
		call _initSRU;

		call _initPanel;

//---------------------------------------------------------------
//		���²�������Flash (����)
//		call _chipErase;

//---------------------------------------------------------------
//		���²���ָ��һ��������������Ϊ R4+20��
//		�����ų���128����ۻأ�����130����(r4=110ʱ)����2����
//		r4 = 6;
//		call _sectorErase;

//---------------------------------------------------------------
//		�������豸��Ϣ(ID����˾���豸��������汾�ȣ�20������)
		i2 = _remoteID;
		r8 = 1 + @_Company + @_DeviceInfo + @_SoftwareVersion + 1;
		r4 = 0;					// ������ƫ�� 0
//		call _writeFlash;
//		�������豸��Ϣ
//---------------------------------------------------------------

//---------------------------------------------------------------
//		�����ճ���(R4=�����, �����豸��Ϣ����֮��)
//		r4=51������Ϊ����ȱʡ����
//		(�� flash.h ע��)
		i2 = _programNo;		// ������ʼ��ַ���� buffers.asm
		r8 = _tempUserData - _programNo;
		r4 = 13;
		// ���ó���ţ�һ���������Ŷ�Ӧ
		// ��51����������
		// �������д51���������� _programNo ������Ӧλ��
		// ���ܿ�ȱ
		dm(_programNo) = r4;
		r4 = 51;					// ���ô������������(1-51)
		call _writeFlash;
//		�����ճ��򲿷�
//---------------------------------------------------------------
//		��д�������������˸EC
blink:
		i4 = _panelCommandTable + 3;
		r4 = 2;
		call _updatePanel;
		lcntr = 0x2000000;
		do (pc, 1) until lce;
			nop;
		i4 = _digitBlackTable;
		r4 = 2;
		call _updatePanel;
		lcntr = 0x2000000;
		do (pc, 1) until lce;
			nop;
		jump blink;

_main.end:


_systemInit:
		bit set MODE2 CADIS;	// Clear cache for rev 0 hardware
								// MODE2 is a latent write
		nop;					// MODE1 latency
		read cache 0;			// as some 2136x isn't enabled properly
		flush cache;
		bit clr MODE2 CADIS;

		LIRPTL = 0;
		IMASKP = 0;
		IRPTL = 0;				// Clear interrupt latch for hardware

	// Set to 32-bit mode and enable CBUFEN
	// We want to disable IRPTEN, saturation, SIMD, 
	// broadcast loads, bit reversal and TRUNCATE. 
	// global interrupt enable, interrupt nesting enable
		bit set MODE1 RND32|SRD2L|SRD2H|SRD1L|SRD1H;  // secondary DAGs
		lcntr = 2, do (pc, end_setup) until lce;
			nop;
			m5 = 0; m6 = 1; m7 = -1;
			m13 = 0; m14 = 1; m15 = -1;
			l0 = 0; l1 = 0; l2 = 0; l3 = 0;
			l4 = 0; l5 = 0; l6 = 0; l7 = 0;
			l8 = 0; l9 = 0; l10 = 0; l11 = 0;
			l12 = 0;l13 = 0;l14 = 0; l15 = 0;
			b0 = 0;	b1 = 0;	b2 = 0;	b3 = 0;
			b4 = 0; b5 = 0; b6 = 0; b7 = 0;
			b8 = 0; b9 = 0; b10 = 0; b11 = 0;
			b12 = 0; b13 = 0; b14 = 0; b15 = 0;
			f11 = 2.0; m0 = MAXBUFFER;
end_setup:
	// primary DAGs, set ALUSAT and TRUNC bits
		bit clr MODE1 TRUNCATE|ALUSAT|SRD2L|SRD2H|SRD1L|SRD1H;
	
		MMASK = BDCST1|BDCST9|SIMD|TRUNCATE|ALUSAT|IRPTEN|BR0|BR8;

		jump  ___lib_setup_stacks;
_systemInit.end:

/*
 * The following initializations rely on several values being established
 * externally, typically by the linker description file.
 */

.extern ldf_stack_space;	/* The base of the stack */
.extern ldf_stack_length;	/* The length of the stack */

/*
 * The linker description file will typically look something like:
 *
 *	MEMORY
 *	{
 *		heap_memory  { START(0x2c000) LENGTH(0x2000) TYPE(DM RAM) }
 *		stack_memory { START(0x2e000) LENGTH(0x2000) TYPE(DM RAM) }
 *	}
 *
 *	...
 *
 *	SECTIONS
 *	{
 *	    stack
 *	    {
 *		ldf_stack_space = .;
 *		ldf_stack_length = MEMORY_SIZEOF(stack_memory);
 *	    } > stack_memory
 *
 *	    heap
 *	    {
 *		ldf_heap_space = .;
 *		ldf_heap_length = MEMORY_SIZEOF(heap_memory);
 *	    } > heap_memory
 *	}
 */

___lib_setup_stacks:
//		PX = pm(___lib_stack_space);
		PX = ldf_stack_space;
		R0 = PX2;
//		PX = pm(___lib_stack_length);
		PX = ldf_stack_length;
		R2 = PX2;
	/* R0 now has stack start, R2 has stack length */
	/* Goal here is that stack start + stack length should be even */
//		R2 = R2 + R0;
//		BTST R2 BY 0;
//		if SZ R2 = R2 - 1;
//		R2 = R2 - R0;
		r2 = r2 - 1;
		PX2 = R2;
		R1 = R0 + R2, B7 = R0;
		R1 = R1 - 1, L7 = R2;
		I7 = R1;
		bit set MODE1 SRD1H; // Enable secondary DAG1
		B6 = B7; // Primary DAG, done in latency slot
		B7 = R0;
		B6 = B7;
		L7 = R2;
		bit clr MODE1 SRD1H; // Enable primary DAG1
		L6 = L7; // Secondary DAG, done in latency slot

		I6 = I7;
		RTS (DB);
		L6 = L7;
		modify(i7, -2);
___lib_setup_stacks.end:

