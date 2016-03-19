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

.section/pm seg_pmco;
// erase entire chip
.global _chipErase;
_chipErase:
	r2 = 0xaa;
	dm(FLASH_START + 0x5555) = r2;
	r2 = 0x55;
	dm(FLASH_START + 0x2AAA) = r2;
	r2 = 0x80;
	dm(FLASH_START + 0x5555) = r2;
	r2 = 0xaa;
	dm(FLASH_START + 0x5555) = r2;
	r2 = 0x55;
	dm(FLASH_START + 0x2AAA) = r2;
	r2 = 0x10;
	dm(FLASH_START + 0x5555) = r2;

	i2 = FLASH_START;
	r0 = _1MS * 1000;					// Max. 1second
	r1 = dm(i2, m5);
	lcntr = r0, do (pc, 4) until lce;
		r2 = pass r1, r1 = dm(i2, m5);
		r2 = r2 XOR r1;
		BTST r2 by 6;
		if SZ jump chip_erased(LA);

chip_erased:
	rts;

_chipErase.end:

//	Erase a sector of parallel flash and polls whether the sector
//	is correctly erased
//	Input: r4(Sector Number)
//	Output: R0(0x0000:success, 0x0101:fail)
//	Changed register: r1, r2
.global _sectorErase;
_sectorErase:
	r2 = SECTOR_FOR_ID;
	r2 = r2 + r4;
	r2 = LSHIFT r2 by 12;				// 4KB/sector
	r2 = BSET r2 by 26;					// BASE ADDR. 0x4000000
	i4 = r2;
	r2 = 0xaa;
	dm(FLASH_START + 0x5555) = r2;
	r2 = 0x55;
	dm(FLASH_START + 0x2AAA) = r2;
	r2 = 0x80;
	dm(FLASH_START + 0x5555) = r2;
	r2 = 0xaa;
	dm(FLASH_START + 0x5555) = r2;
	r2 = 0x55;
	dm(FLASH_START + 0x2AAA) = r2;
	r2 = 0x30;
	dm(0, i4) = r2;
	
	r2 = 0xff;
	r0 = _1MS * 100;					// Max. 100ms
	lcntr = r0, do (pc, 3) until lce;
		r1 = dm(0, i4);
		comp (r1, r2);
		if EQ jump (pc, successErase)(LA), r0 = r0 - r0;// sucess code

	r0 = 0x0101;						// err code
successErase:
	rts;
_sectorErase.end:


// This program writes data into parallel flash and polls whether
// the data is written correctly
//	Input - R4, program number
//	i2: data in system ram
//	i4: flash
//	Output - R0, error code(success 0x0000, fail 0x0102)
//	Changed registers: r1,  r2

.global _writeFlash;
_writeFlash:
	call _sectorErase;					// i4 -> Sector base address
	if NE rts;
	
	lcntr = r8, do flashparameter until lce;
		r2 = 0xaa;
		dm(FLASH_START + 0x5555) = r2;
		r2 = 0x55;
		dm(FLASH_START + 0x2AAA) = r2;
		r2 = 0xa0;
		dm(FLASH_START + 0x5555) = r2;

		r6 = dm(i2, m6);				//data is 16 bits wide, only LSB valid
		dm(i4, m6) = r6;				// write one BYTE
		r6 = FEXT r6 by 0:8;

		r2 = _1MS / 10;					// 100us
		lcntr = r2, do (pc, 3) until lce;
			r1 = dm(m7, i4);
			comp (r6, r1);
			if EQ jump (pc, successByte)(LA), r0 = r0 - r0;

		r0 = 0x0102;
		jump errorWrite(LA);
successByte:
flashparameter:
		nop;

errorWrite:
	rts;
_writeFlash.end:

//	check if this sector contains valid paramters for this program No.
//	Input:
//	-- R4: Program Number(sector number related to ID sector)
//	-- R0: parameter index
//		0: programNo
//		1: programValid
//		2: recalllock
//		3: protection
//	changed registers: r2, m2, i4
//	return: r2(parameter read)
.global _programCheck;
_programCheck:
	r2 = SECTOR_FOR_ID;
	r2 = r2 + r4;
	r2 = LSHIFT r2 by 12;				// 4KB/sector
	r2 = BSET r2 by 26;					// BASE ADDR. 0x400 0000
	i4 = r2;

	m2 = r0;
	r2 = dm(m2, i4);
	rts;
_programCheck.end:

.global _readFlash;
// load data from flash(I12) to SRAM(I2)
//	changed registers: r2, i2, i12
//	return: r2(parameter read)
_readFlash:
	r2 = SECTOR_FOR_ID;
	r2 = r2 + r4;
	r2 = LSHIFT r2 by 12;				// 4KB/sector
	r2 = BSET r2 by 26;					// BASE ADDR. 0x400 0000
	i12 = r2;
	r2 = pm(i12, m14);
	lcntr = r8, do (pc, 1) until lce;
		dm(i2, m6) = r2, r2 = pm(i12, m14);

	rts;
_readFlash.end:

