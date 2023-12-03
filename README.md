# No More Plan MBR 

## Chainloading MBR for Plan9 and Linux

I wanted to have a dual boot with Plan9 and Linux on my computer, but couldn't use Plan9 MBR, which only supports the system itself, nor GRUB or other bootloaders that would not accept to load a kernel from an unknown filesystem. Hence, an hybrid approach was chosen, so as not to pollute any of the operating systems: GRUB is installed regularly (after MBR), and the Plan9 VBR is kept as is on the Plan9 partition.

This system cannot work without a dispatcher allowing to choose which system to boot from: that is where No More Plan enters into play: it simply chainloads one of the VBR (out of four maximum) and passes execution to it. A fifth option also allows booting from after-MBR sector (ie. GRUB).

## Usage

Code is provided for a GNU `as` linker, so it cannot be built on Plan9 directly. It consists of a single assembly file for x86_64, `mbr.S` and a linker file for GNU `ld`. To get the binary MBR, run:

```bash
gcc -E mbr.S | as --32 -mx86-used-note=no -o mbr.o -
ld -T mbr.ld -o mbr.bin mbr.o
```

Then burn the new MBR to an existing disk, effectively erasing the one provided by the system. No guaranteed is given for the program, which may not work depending on your BIOS setup.

## Inspirations

The code in this repository, licensed under GNU GPL v3.0, was greatly inspired by MBR included in the GNU GRUB project, Plan9 project and FreeBSD.

