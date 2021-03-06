Bootsplash
----------
Small bootable program that shows a splash effect every time you boot it up, and
when you hit any key on the keyboard, it proceeds to load the actual system (or
your regular boot loader) off the hard drive. It also presents a menu of all
available drives in the system, and can chain-load the boot sector of any one
of them, by pressing the corresponding number key.

![shot](http://nuclear.mutantstargoat.com/sw/misc/bootsplashcrt-thumb.jpg)

Video: https://www.youtube.com/watch?v=zcIpD00TYNg

Author: John Tsiombikas <nuclear@member.fsf.org>

Not copyrighted, public domain software. Feel free to use it any way you like.
If public domain is not legally recognized in your country, you may instead use
it under the terms of the Creative Commons CC0 license.

Future improvements (TODO list):

  - Option to load active partition instead of MBR from the selected boot device
    to make bootsplash itself installable on the MBR (as it is, it would just
    infinitely load itself).
  - Add timeout to boot automatically if no key is pressed for a certain amount
    of time.

Build
-----
To build bootsplash you need the netwide assembler (nasm). If you want to
customize the image used by the effect, you'll also need a C compiler to build
the RLE encoder under `rle`.

The data files are not in the repo. You'll need to get them from one of the
release archives.

  - `nuclear.pgm`: 320x200 greyscale image used by the effect in binary Portable
    GreyMap format.  This is fed into the `rle` encoder to produce `nuclear.rle`
    which is `incbin`-ed into the bootsplash program.
  - `fire.ppm`: 256x1 RGB image in binary Portable PixMap format. The header gets
    stripped and the resulting `fire.pal` file is `incbin`-ed into the program.
  - `ui.png`: boot menu UI graphics. It gets dumped as `ui.img` with `pngdump`
    and `incbin`-ed into the bootsplash program.

If you don't want to customize the effect, simply copy the final files
(`nuclear.rle`, `fire.pal`, and `ui.img`) and type make.

To install onto a floppy or a USB stick, just use `dd`.
