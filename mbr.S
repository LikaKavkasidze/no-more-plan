/*
	No More Plan MBR - Chainloading MBR for Plan9 and Linux
	Copyright (C) 2023 Titouan (Stalone) S.

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#define NMP_BASE_ADDR 0x7C00
#define NMP_RELOC_ADDR 0x600
#define NMP_CHAIN_GRUB 0x8000
#define NMP_CHAIN_VBR 0x7C00

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
	push %dx
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
	// If the char is NUL, stop
	cmp $0,%al
	jne print_char
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
disk_check:
	// 41 = EDD Installation Check
	mov $0x41,%ah
	// Required parameter for interrupt
	mov $0x55AA,%bx
	// 13 = Disk Services
	int $0x13
	// CF signals no support
	jc end
choose_message:
	// Display a message for choosing the partition
	mov $ask_str,%si
	mov $test_parts,%di
	jmp print_str
test_parts:
	// Get start of first partition
	// See, registers are quite scarse, especially in
	// 16-bit mode, where only %bx, %si and %di can be
	// use for base/index expressions.
	// %si and %di are already used for string display
	// so only %bx is left.
	mov $_start,%bx
	add $0x1BE,%bx
	// Reset partition counter (CX)
	xor %cx,%cx
part_loop:
	// Check for boot signature to see if all partitions have
	// been looped over
	mov (%bx),%dl
	cmp $0x55,%dl
	je part_loop_end
	// Increment partition counter: used to display partition number
	add $0x1,%cx
	// Check if partition is bootable
	cmp $0x80,%dl
	jne part_loop_next
part_loop_display:
	// Convert partition number to ASCII number
	mov %cx,%ax
	add $0x30,%ax
	// Display key for partition
	mov $extra_part_str,%si
	mov %ax,2(%si)
	mov $part_loop_next,%di
	jmp print_str
part_loop_next:
	// Access next partition: PTE length is 16
	add $0x10,%bx
	// Test next partition
	jne part_loop
part_loop_end:
	// Display extra key for after-MBR loading (eg. GRUB)
	mov $extra_part_str,%si
	movb $0x35,2(%si)
	mov $wait_input,%di
	jmp print_str
wait_input:
	// 01 = Read Input Status
	movb $0x1,%ah
	// 16 = Keyboard Services
	int $0x16
	// Loop until keypress
	je wait_input
read_part_number:
	// 00 = Get Keystroke
	movb $0x0,%ah
	// 16 = Keyboard Services
	int $0x16
	// BIOS scan code is between 3B and 3F for F1-F5
	cmp $0x3B,%ah
	jb wait_input
	cmp $0x3F,%ah
	ja wait_input
	// Convert F-key to partition number
	subb $0x3B,%ah
	// Save partition number
	push %ax
	// Indicate chainloading is in progress
	mov $end_str,%si
	mov $valid_partition,%di
	jmp print_str
valid_partition:
	// Restore partition number
	pop %ax
	// F5 should load next sector while F1-F4 chainloads VBR
	cmp $4,%ah
	jne load_vbr
load_next_sector:
	// GRUB expects to be loaded at 0x8000
	movl $NMP_CHAIN_GRUB,%eax
	// Load sector 1, right after MBR
	movl $0x1,%ebx
	jmp read_lba
load_vbr:
	// Shift to move AH to AL [>> 8] and multiply by 0x10 [<< 4]
	sar $4,%ax
	// Get LBA value of partition to boot
	mov $_start,%si
	add $0x1BE,%si
	add %ax,%si
	movl 0x8(%si),%ebx
	// VBR expects to be loaded at 0x7C00
	movl $NMP_CHAIN_VBR,%eax
read_lba:
	// Save address to be chainloaded
	push %eax
	// SI = DAP location
	mov $disk_address_packet,%si
	// Append start sector and load address to DAP
	movl %eax,0x4(%si)
	movl %ebx,0x8(%si)
	// 42 = Extended sector read
	mov $0x42,%ah
	// 13 = Disk Services
	int $0x13
	// Check for error and jump to loaded code
	jc end
	// Restore chainload address and disk number
	pop %eax
	pop %dx
	// The great jump! Go to second stage
	jmp *%eax
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
	.4byte 0x00000000
	// LBA start sector
	.8byte 0x0000000000000000

hello_str:
	.asciz "No. More. Plan.\r\n"

ask_str:
	.asciz "Partition to boot?"

extra_part_str:
	.asciz " F5"

end_str:
	.asciz "\r\nBooting...\r\n"

error_str:
	.asciz "An error occured."

