OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)
ENTRY(_start)

SECTIONS {
	. = 0x0600;
	.text : {
		_start = .;
		*(.text)
	}
}