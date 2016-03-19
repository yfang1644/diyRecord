// parallel flash on EC2600

#include <def21375.h>

#include <sru.h>

#include "flash.h"

.global TEST_FAIL;
.extern SECTOR_ERASE;
.extern CHIP_ERASE;
.extern FLASH_RESET;
.extern PROGRAM_FLASH;
.extern VERIFY_FLASH;

.extern _initSRU;
.extern _updatePanel, _initPanel;
.extern _panelInitTable, _flashOK, _flashError;
.extern _initPLL;

// 16-bit data section
.section/dm seg_sdram;				//short-word address space
.var my_file[] = "EC2600-56.ldr";	//32-bit loader file
.global my_file;

.section/pm seg_rth;

__EMUI:         // 0x00: Emulator interrupt (highest priority, read-only, non-maskable)
        nop; nop; nop; nop;
__RSTI:         // 0x04: Reset (read-only, non-maskable)
		nop;    // <-- (this line is not executed)
		jump _main;
		nop;
		nop;

//--------------------------------------------------------------------------
// Main Program Section
.section/pm seg_pmco;
_main:

	m5 = 0; m6 = 1; m7 = -1;
    // Set up the AMI for Bank 1
    // 8-bit bus width
    // 23 Wait States
    // Packing Disabled
    call _initPLL;
	ustat1 = AMIEN|BW8|WS23|PKDIS|AMIFLSH;
	dm(AMICTL1) = ustat1;
	ustat1 = dm(EPCTL);
	bit set ustat1 B0SD;
	bit clr ustat1 B1SD|B2SD|B3SD;
	dm(EPCTL) = ustat1;
	call _initSRU;

	call _initPanel;
	i4 = _panelInitTable;
	r4 = @_panelInitTable/3;
	call _updatePanel;

	call SETUP;				// Erase the necessary amount of space

	call PROGRAM_FLASH;		// Program the flash

	call VERIFY_FLASH;		// Verify the data that was just programmed

//--------------------------------------------------------------------------
// Wait here after programming is successful, toggle all of the LEDs forever
	ustat1 = 0;
	dm(AMICTL1) = ustat1;  //disables the AMICTL

//--------------------------------------------------------------------------
//Use FLAGS to show that the process completed.
//Indicate whether the process was error-free

	r4 = @_flashOK / 3;
	i4 = _flashOK;
	call _updatePanel;
	jump (pc, 0);

TEST_FAIL:
	r4 = @_flashOK / 3;
	i4 = _flashError;
	call _updatePanel;
	jump (pc, 0);
_main.end:
TEST_FAIL.end:


// --------------------------------------------------------------------------
// Setup Resets the flash, Checks the file size, and erases the needed amount of flash space
SETUP:
	call FLASH_FILE_SIZE;   //be sure the data will fit in the flash
	call FLASH_RESET;       //issue the flash reset command
//	call SECTOR_ERASE;      //erases proper # of sectors and verifies erasure
	call CHIP_ERASE;
	rts;

// -------------------------------------------------------------------------
// Check the size of the file and compare against max size
FLASH_FILE_SIZE:
	r5 = length(my_file)*BYTES;			// read the # of bytes to program
	r6 = 512*1024;						// size of flash is 512Kx8
	comp (r5, r6);
	if ge jump TEST_FAIL;				// verify file will fit in flash
	rts;

