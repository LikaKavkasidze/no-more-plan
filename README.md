# No More Plan – Sideloading MBR for Plan9 and Linux

I wanted to have a dual boot with Plan9 and Linux on my computer, but couldn't use Plan9 MBR, which only supports the system itself, nor GRUB or other bootloaders that would not accept to load a kernel from an unknown filesystem. Hence, an hybrid approach was chosen, so as not to pollute any of the operating systems: GRUB is installed on the Linux partition (as VBR), and the Plan9 VBR is kept as is on the Plan9 partition.

This system cannot work without a dispatcher allowing to choose which system to boot from: that is where No More Plan enters into play: it simply sideloads one of the VBR (out of four maximum) and passes execution to it.

Code is provided for a GNU `as` linker, so it cannot be built on Plan9 directly. It consists of a single assembly file for x86_64, `mbr.S` and a linker file for GNU `ld`. To get the binary MBR, run:

```bash
gcc -E mbr.S | as --32 -mx86-used-note=no -o mbr.o -
ld -T mbr.ld -o mbr.bin mbr.o
```

Then burn the MBR to an existing Plan9 disk, effectively erasing the one provided by the Plan9 system. No guaranteed is given for the program, which may not work depending on your BIOS setup.
