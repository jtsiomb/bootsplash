bin = bootsplash.bin
img = bootsplash.img

$(img): $(bin)
	dd if=/dev/zero of=$@ bs=512 count=2880
	dd if=$< of=$@ bs=512 conv=notrunc

$(bin): bootsplash.asm
	nasm -f bin -o $@ $<

.PHONY: run
run: $(img)
	qemu-system-i386 -fda $<

.PHONY: debug
debug: $(img)
	qemu-system-i386 -S -s -fda $<
