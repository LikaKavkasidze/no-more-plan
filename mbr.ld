OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i386)

MEMORY {
	NMP_BASE (RX) : ORIGIN = 0x7C00, LENGTH = 512
	NMP_RELOC (RX) : ORIGIN = 0x0600, LENGTH = 512
}

SECTIONS {
	.text : {
		. = ORIGIN(NMP_RELOC);
		_start = .;
		*(.text)
	} > NMP_RELOC AT > NMP_BASE
}

ENTRY(_start)
