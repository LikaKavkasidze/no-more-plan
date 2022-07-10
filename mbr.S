#define NMP_BASE_ADDR 0x7C00
#define NMP_RELOC_ADDR 0x600

.code16
.section .text
.globl _start
_start:
	jmp after_bpb
disk_address_packet:
	// The very beginning of the MBR is available for code
	// So we optimize space by having the disk packet here
	.byte 0x10
	.byte 0
	.word 0x01
	.long NMP_BASE_ADDR
bpb:
	// BIOS parameter block
	// Useless FAT parameters
	.rept 14
	.byte 0
	.endr
	// Physical sectors per track
	.word 63
	// Number of heads
	.word 255
	// More useless FAT parameters
	.rept 73
	.byte 0
	.endr
after_bpb:
	// Disable interrupts
	cli
	// Zero segment registers
	xor %ax, %ax
	mov %ax, %ds
	mov %ax, %ss
	mov %ax, %es
	// Set up stack
	mov $NMP_RELOC_ADDR,%ebp
	mov %ebp,%esp
	// DX register may contain boot device, so push to keep it
	push %dx
relocate_mbr:
	// Set relocation source
	mov $NMP_BASE_ADDR,%si
	// Set relocation destination
	mov $NMP_RELOC_ADDR,%di
	// Relocation byte count
	mov $512,%cx
	// Count direction: backward
	mov $0x1,%dx
	// Relocate code
	rep
	movsb
	// Recover value of DX register
	pop %dx
	// Jump to relocated code
	jmp relocated_segment+NMP_RELOC_ADDR-NMP_BASE_ADDR
relocated_segment:
	// Set SI to base string address
	mov $hello_str,%si
print_str:
	// Access to char pointed by SI
	mov (%si),%al
	// 0E = Write Character in TTY Mode
	mov $0x0E,%ah
	// 10 = Video Services
	int $0x10
	// Point to the next char
	inc %si
	// If the char was NUL, stop
	cmp $0,%al
	// Loop for characters
	jne print_str
test_parts:
	// Get start of first partition
	mov $_start,%si
	add $0x1BE,%si
part_loop:
	// Extract bootable flag
	mov (%si),%bl
	// Test for bootable partition
	cmp $0x80,%bl
	// Skip saving if non-bootable
	jne part_loop_next
	// Save partition start LBA
	pushl 0x8(%si)
part_loop_next:
	// Access next partition
	add $0x10,%si
	// Check for end
	cmp $0x7FE,%si
	// Test next partition
	jne part_loop
	// If no bootable partition was found
	cmp %ebp,%esp
	// Early ending
	je end
valid_partition:
	// 41 = EDD Installation Check
	mov $0x41,%ah
	// Required parameter for interrupt
	mov $0x55AA,%bx
	// 13 = Disk Services
	int $0x13
	// CF signals no support
	jc end
read_lba:
	// SI = DAP location
	mov $disk_address_packet,%si
	// Get last valid partition
	popl %ebx
	// Append start sector to DAP
	movl %ebx,0x8(%si)
	// 42 = Extended sector read
	mov $0x42,%ah
	// 13 = Disk Services
	int $0x13
	// Go to 9LOAD
	jmp NMP_BASE_ADDR
end:
	hlt

hello_str:
	.asciz "No. More. Plan.\r\n"

ask_str:
	.asciz "Partition to boot? "