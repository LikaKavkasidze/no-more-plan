#define NMP_BASE_ADDR 0x7C00
#define NMP_RELOC_ADDR 0x600

.code16
.att_mnemonic
.section .text
.globl _start
_start:
	// Disable interrupts while no stack is available
	cli
	// Ensure string operations will increment index register
	cld
	// Zero segment registers: no assumption shall be made about
	// their initial state
	xor %ax, %ax
	mov %ax, %ds
	mov %ax, %ss
	mov %ax, %es
	// Set up stack
	mov $NMP_BASE_ADDR,%bp
	mov %bp,%sp
	// Interrupts can be triggered again
	sti
	// Keep DX register as it may contain boot device
	push %dx
relocate_mbr:
	// Relocate code from BASE_ADDR to RELOC_ADDR because the chainloaded
	// bootloader will be loaded at the initial MBR address
	mov $NMP_BASE_ADDR,%si
	mov $NMP_RELOC_ADDR,%di
	mov $512,%cx
	// Set backward count direction
	mov $0x1,%dx
	rep
	movsb
	// Recover value of DX register
	pop %dx
	// Far jump to relocated code because some bugging BIOSes do not implement JMP correctly
	ljmp $0,$relocated_segment
relocated_segment:
	// Set SI to base string address
	mov $hello_str,%si
	// Set return address
	mov $choose_message,%di
print_str:
	// Access to char pointed by SI
	mov (%si),%al
	// Skip over jump
	cmp $0,%al
	jne print_char
	// If the char is NUL, stop
	jmp *%di
print_char:
	// 0E = Write Character in TTY Mode
	mov $0x0E,%ah
	// 10 = Video Services
	int $0x10
	// Point to the next char
	inc %si
	// Loop for characters
	jmp print_str
choose_message:
	// Display a message for choosing the partition
	mov $ask_str,%si
	mov $test_parts,%di
	jmp print_str
test_parts:
	// Get start of first partition
	mov $_start,%si
	add $0x1BE,%si
	// Reset partition counter (CX)
	xor %cx,%cx
part_loop:
	// Check for boot signature to see if all partitions have
	// been looped over
	mov (%si),%bl
	cmp $0x55,%bl
	je part_loop_end
	// Increment partition counter: used to display partition number
	add $0x1,%cx
	// Check if partition is bootable
	cmp $0x80,%bl
	jne part_loop_next
part_loop_display:
	// Displays an "F" (0x46) char
	mov $0x46,%al
	// 0E = Write Character in TTY Mode
	mov $0x0E,%ah
	// 10 = Video Services
	int $0x10
	// Convert partition number to ASCII number
	mov %cl,%al
	add $0x30,%al
	// 0E = Write Character in TTY Mode
	mov $0x0E,%ah
	// 10 = Video Services
	int $0x10
part_loop_next:
	// Access next partition: PTE length is 16
	add $0x10,%si
	// Test next partition
	jne part_loop
part_loop_end:
	// Display extra key for after-MBR loading (eg. GRUB)
	mov $extra_part_str,%si
	mov $wait_input,%di
	jmp print_str
wait_input:
	// 01 = Read Input Status
	movb $0x1,%ah
	// 16 = Keyboard Services
	int $0x16
	// Loop until keypress
	je wait_input
	// Indicate chainloading is in progress
	mov $end_str,%si
	mov $valid_partition,%di
	jmp print_str
valid_partition:
	// 41 = EDD Installation Check
	mov $0x41,%ah
	// Required parameter for interrupt
	mov $0x55AA,%bx
	// 13 = Disk Services
	int $0x13
	// CF signals no support
	jc end
read_part_number:
	// 00 = Get Keystroke
	movb $0x0,%ah
	// 16 = Keyboard Services
	int $0x16
	// Convert F-key to partition number: BIOS scan code is
	// between 3B and 3F for F1-F5
	subb $0x3B,%ah
	// F5 should load next sector
	movl $0x1,%ebx
	cmp $4,%ah
	je read_lba
	// Shift to move AH to AL [>> 8] and multiply by 0x10 [<< 4]
	sar $4,%ax
	// Get LBA value of partition to boot
	mov $_start,%si
	add $0x1BE,%si
	add %ax,%si
	movl 0x8(%si),%ebx
read_lba:
	// SI = DAP location
	mov $disk_address_packet,%si
	// Append start sector to DAP
	movl %ebx,0x8(%si)
	// 42 = Extended sector read
	mov $0x42,%ah
	// 13 = Disk Services
	int $0x13
	// Check for error and jump to loaded code
	jc end
	jmp NMP_BASE_ADDR
end:
	// Display error message and halt
	mov $error_str,%si
	mov $end_halt,%di
	jmp print_str
end_halt:
	hlt

disk_address_packet:
	// Length of the DAP
	.byte 0x10
	.byte 0x00
	// Number of sectors to read
	.2byte 0x0001
	// Pointer to the memory buffer
	.4byte NMP_BASE_ADDR
	// LBA start sector
	.8byte 0x0000000000000000

hello_str:
	.asciz "No. More. Plan.\r\n"

ask_str:
	.asciz "Partition to boot? "

extra_part_str:
	.asciz " F5"

end_str:
	.asciz "\r\nBooting...\r\n"

error_str:
	.asciz "An error occured."

