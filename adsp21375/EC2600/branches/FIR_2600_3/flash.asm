/////////////////////////////////////////////////////////////////////////////
//NAME:	flash.asm (SST39VF040 parallel Flash 8-bit x 512K)
//DATE:	2010-10-04
//
//Description:
//		Sector size is 4KB. total program is about 20KB. 100KB reserved.
//		512K/4K=128 sectors
//
/////////////////////////////////////////////////////////////////////////////
#include "constant.h"
#include "flash.h"
#include "lib_glob.h"

.section/pm seg_pmco;

//	Erase a sector of parallel flash and polls whether the sector
//	is correctly erased
//	Input: r4(program Number)
//	Output: EQ:success, NE:fail(r0 = 1)
//	Changed register: r2
.global _sectorErase;
_sectorErase:
	r2 = SECTOR_FOR_ID;
	r2 = r2 + r4;
	r2 = LSHIFT r2 by 12;				// 4KB/sector
	r2 = BSET r2 by 26;					// BASE ADDR. 0x4000000
	i4 = r2;
	FLASH(0x5555, 0xaa);
	FLASH(0x2AAA, 0x55);
	FLASH(0x5555, 0x80);
	FLASH(0x5555, 0xaa);
	FLASH(0x2AAA, 0x55);
	r2 = 0x30;
	dm(i4, m5) = r2;

	r2 = 0xff;
	r0 = _1MS * 25;					// Max. 100ms
	lcntr = r0, do (pc, 4) until lce;
		r0 = dm(i4, m5);
		comp (r0, r2);
		if EQ jump (pc, successErase)(LA), r0 = r0 - r0;// success code
		nop;

	r0 = 1;
successErase:
	EXIT;
_sectorErase.end:


// This program writes data into parallel flash and polls whether
// the data is written correctly
//	Input - R6(D0-D7)
//	i2: data in system ram
//	i4: flash
//	Output - EQ:success, NE:fail(r0 = 2)
//	Changed registers:  r2

.global _writeFlash, _writeFlash_no_erase;
_writeFlash:
	CCALL (_sectorErase);				// i4 -> Sector base address
	if NE jump errorWrite;

_writeFlash_no_erase:

	lcntr = r8, do flashparameter until lce;
		FLASH(0x5555, 0xaa);
		FLASH(0x2AAA, 0x55);
		FLASH(0x5555, 0xa0);

		r6 = dm(i2, m6);				//data is 16 bits wide, only LSB valid
		r6 = FEXT r6 by 0:8, dm(i4, m6) = r6;	// write one BYTE

		lcntr = _1MS/10, do (pc, 4) until lce;	  // 100us
			r2 = dm(m7, i4);
			comp (r6, r2);
			if EQ jump (pc, successByte)(LA), r0 = r0 - r0;
			nop;

		r0 = 2;
		jump errorWrite(LA);
		nop;
successByte:
		nop;
flashparameter:
		nop;

errorWrite:
	EXIT;
_writeFlash_no_erase.end:
_writeFlash.end:


.global _readFlash;
// load data from flash(I12) to SRAM(I2)
//	changed registers: r2, i2, i12
//	return: none
_readFlash:
	r2 = SECTOR_FOR_ID;
	r2 = r2 + r4;
	r2 = LSHIFT r2 by 12;				// 4KB/sector
	r2 = BSET r2 by 26;					// BASE ADDR. 0x400 0000
	i12 = r2;
	r2 = pm(i12, m14);
	lcntr = r8, do (pc, 1) until lce;
		dm(i2, m6) = r2, r2 = pm(i12, m14);

	EXIT;
_readFlash.end:

