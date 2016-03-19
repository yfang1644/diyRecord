#define	FLASH_START		0x4000000
#define	FLASH_SIZE		0x800000
#define	SECTOR_SIZE		4096

#define BYTES			4
// Flash 文件格式， 32bit
//	4 * 8bits = 32 bit logical data width
//	2 * 8bits = 16 bit logical data width
//	1 * 8bits =  8 bit logical data width


#define	SECTOR_FOR_ID		20		// machine ID saved in sector 64.
#define	SECTOR_FOR_PARAM	21		// 50 sectors used for 50 program

/*
sector 0~19 : 20*4K*8bits for DSP PROGRAM
sector 20~20: 4K*8bits, Machine information(ID, Version, Vendor, etc.)
sector 21~71: 51*4K*8bits, Default(51) and Factory Preset(1~50) Program
sector 72~121:50*4K*8bits, User Program(No=51~99)
sector 121~127: unused
*/

