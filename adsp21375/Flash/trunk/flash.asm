/********************************************************************
 *  This program checks whether the flash is erased.                *
 *  If the flash is not erased right it gets stuck here.            *
 *  Input - Word_To_Write                                           *
 *  Output - None                                                   *
 ********************************************************************/

#include "flash.h"

.extern WRITE_FLASH_BYTE, my_file, TEST_FAIL;

.section/pm seg_pmco;

.global CHIP_ERASE;
CHIP_ERASE:
	r0 = 0xaa;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;
	r0 = 0x55;
	dm(FLASH_START_ADDRESS + 0x2AAA) = r0;
	r0 = 0x80;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;
	r0 = 0xaa;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;
	r0 = 0x55;
	dm(FLASH_START_ADDRESS + 0x2AAA) = r0;
	r0 = 0x10;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;

	r0 = 0xff;
	r1 = dm(FLASH_START_ADDRESS);
	comp (r0, r1);
	if NE jump (pc, -2);			//check if sector is erased
	nop;
	nop;
	nop;
	rts;

CHIP_ERASE.END:

/********************************************************************
 *  This program reset the flash                                    *
 *  Input - None                                                    *
 *  Output - None                                                   *
 ********************************************************************/

.global FLASH_RESET;
FLASH_RESET:
	// Write the RESET command to any address in the same bank as the flash
	r0 = 0xaa;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;
	r0 = 0x55;
	dm(FLASH_START_ADDRESS + 0x2AAA) = r0;
	r0 = 0x90;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;

	r0 = dm(FLASH_START_ADDRESS);
	r1 = dm(FLASH_START_ADDRESS+1);		// read device ID
	r0 = 0xF0;
	dm(FLASH_START_ADDRESS) = r0; //Command for RESET of FLASH
	rts;

FLASH_RESET.END:

/********************************************************************
 *  This program Programs the flash with the input file             *
 *  Input - None                                                    *
 *  Output - None                                                   *
 ********************************************************************/

.global PROGRAM_FLASH;
PROGRAM_FLASH:

	i4 = FLASH_START_ADDRESS;
	i2 = my_file;

	lcntr=@my_file, do PROGRAM_FLASH_LOOP until lce; //each loop iteration writes four 8-bit flash locations
		call WRITE_FLASH_BYTE(DB); //write 8 bits of the data
		r6 = dm(i2, m6);         //data is 16 bits wide in 'my_file'
		modify (i4, m6);

		call WRITE_FLASH_BYTE(DB); //write 8 bits of the data
		r6 = lshift r6 by -8;   //get the other 8 bits
		modify (i4, m6);

		call WRITE_FLASH_BYTE(DB); //write 8 bits of the data
		r6 = lshift r6 by -8;   //get the other 8 bits
		modify (i4, m6);

		call WRITE_FLASH_BYTE(DB); //write 8 bits of the data
		r6 = lshift r6 by -8;   //get the other 8 bits
		modify (i4, m6);
PROGRAM_FLASH_LOOP:
        nop;

	rts;
PROGRAM_FLASH.END:

/********************************************************************
 *  This program erases the sector and updates the sector addresses *
 *  until all the sectors are erased                                *
 *  Input - None                                                    *
 *  Output - None                                                   *
 ********************************************************************/

.global SECTOR_ERASE;

SECTOR_ERASE:
	i4 = FLASH_START_ADDRESS;		//first sector address
	m1 = SECTOR_SIZE;

	lcntr = NUMBER_SECTORS, do sectors until lce; //this loop erases and verifies one sector per iteration
		r0 = 0xaa;
		dm(FLASH_START_ADDRESS + 0x5555) = r0;
		r0 = 0x55;
		dm(FLASH_START_ADDRESS + 0x2AAA) = r0;
		r0 = 0x80;
		dm(FLASH_START_ADDRESS + 0x5555) = r0;
		r0 = 0xaa;
		dm(FLASH_START_ADDRESS + 0x5555) = r0;
		r0 = 0x55;
		dm(FLASH_START_ADDRESS + 0x2AAA) = r0;
		r0 = 0x30;
		dm(0, i4) = r0;

		r0 = 0xff;
		r1 = dm(0, i4);
		comp (r0, r1);
		if NE jump (pc, -2);		//check if sector is erased
		modify(i4, m1);
		nop;
sectors:
		nop;

	rts;
SECTOR_ERASE.END:

/********************************************************************
 *  This program verifies whether the flash is programmed right     *
 *  with the input file                                             *
 *  Input - None                                                    *
 *  Output - None                                                   *
 ********************************************************************/

.global VERIFY_FLASH;
VERIFY_FLASH:
	i4 = FLASH_START_ADDRESS;
	i2 = my_file;
	lcntr = @my_file; do VERIFY until lce;
		r2 = r2 - r2, r0 = dm(i4, m6);	//fetch ONE bytes from flash
		r2 = FDEP r0 BY 0:8, r0 = dm(i4, m6);
		r2 = r2 OR FDEP r0 BY 8:8, r0 = dm(i4, m6);
		r2 = r2 OR FDEP r0 BY 16:8, r0 = dm(i4, m6);
		r2 = r2 OR FDEP r0 BY 24:8, r4 = dm(i2, m6); //four bytes from source

		comp(r2, r4);					//compare
		if ne jump TEST_FAIL(LA);

VERIFY: nop;

	rts;
VERIFY_FLASH.END:

/********************************************************************
 *  This program writes data into parallel flash and polls whether  *
 *  the data is written correctly                                   *
 *  Input - r6 D7-D0, i4 ->External_Byte_Address                    *
 *  Output - None                                                   *
 ********************************************************************/

.global WRITE_FLASH_BYTE;
WRITE_FLASH_BYTE:

// These are the command words for write for the AMD flash
	r0 = 0xaa;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;

	r0 = 0x55;
	dm(FLASH_START_ADDRESS + 0x2AAA) = r0;

	r0 = 0xa0;
	dm(FLASH_START_ADDRESS + 0x5555) = r0;

	r0 = FEXT r6 by 0:8;
	dm(m7, i4) = r0;

	r1 = dm(m7, i4);
	comp(r0, r1);
	if NE jump (pc, -2);
	rts;
WRITE_FLASH_BYTE.END:

