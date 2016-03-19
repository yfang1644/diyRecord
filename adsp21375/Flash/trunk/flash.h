#define FLASH_START_ADDRESS		0x4000000
#define FLASH_SIZE				0x800000
#define SECTOR_SIZE				4096
#define NUMBER_SECTORS			(LENGTH(my_file)*BYTES >>12) + 1
//i.e. if length of file in bytes is 0x1ffff, 1 sector= 0xffff, shift by 16 gives us 1+1 etc.
#define BYTES					4
//i.e. 4 * 8bits = 32 bit logical data width
//     2 * 8bits = 16 bit logical data width
//     1 * 8bits =  8 bit logical data width

