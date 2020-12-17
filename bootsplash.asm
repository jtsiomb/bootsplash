	org 7c00h
	bits 16

BOOT_DEV equ 80h

stacktop equ 7b00h
boot_driveno equ 7b00h	; 1 byte
stage2_size equ stage2_end - stage2_start

spawn_rate equ 512
framebuf equ 40000h

%macro floppy_motor_off 0
	pushf
	and dl, 80h
	jnz %%end	; skip if high bit is set (i.e. it's not a floppy)
	mov dx, 3f2h
	in al, dx
	and al, 0fh
	out dx, al
%%end:	popf
%endmacro

start:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov gs, ax
	mov fs, ax

	mov sp, stacktop
	mov [boot_driveno], dl

	; load the rest of the code at 7e00
	xor ax, ax
	mov es, ax
	mov bx, stage2_start
	mov ah, 2		; read sectors call
	mov al, (stage2_size + 511) / 512  ; num sectors
	mov cx, 2		; ch: cylinder, cl: sector
	xor dx, dx		; dh: head
	mov dl, [boot_driveno]
	int 13h
	floppy_motor_off	; turn off floppy motor (if dl is < 80h)
	jnc stage2_start	; loaded successfully, jump to it

	; failed to load second sector
	mov ax, str_load_fail
	call printstr
.hang:	cli
	hlt
	jmp .hang

	; expects string ptr in ax
printstr:
	mov si, ax
.loop:	mov al, [si]
	inc si
	test al, al
	jz .done
	mov ah, 0eh
	mov bx, 7
	int 10h
	jmp .loop
.done:	ret

str_load_fail db "Failed to load second stage!",0
str_booting db "Booting system... ",0
str_bootfail db "failed!",0


	times 510-($-$$) db 0
bootsig dw 0xaa55

	; start of the second stage
stage2_start:
	pushf
	cli
	call splash
	popf

	xor ax, ax
	mov es, ax
	mov ds, ax

	mov ax, str_booting
	call printstr

	; blank out the existing boot signature to really see if a boot sector
	; gets loaded correctly
	xor ax, ax
	mov [bootsig], ax

	; load from BOOT_DEV into 7c00h and jump
	mov bx, 7c00h
	mov ax, 0201h		; ah: call 2 (read sectors), al: count = 1
	mov cx, 1		; ch: cylinder 0, cl: sector 1
	mov dx, BOOT_DEV	; dh: head 0, dl: boot device number
	int 13h
	floppy_motor_off	; turn floppy motor off (if dl < 80h)

	jc .fail		; BIOS will set the carry flag on failure
	mov ax, [bootsig]
	cmp ax, 0aa55h
	jnz .fail		; fail if what we loaded is not a valid boot sect

	mov ax, 0e0dh
	mov bx, 7
	int 10h
	mov ax, 0e0ah
	int 10h

	jmp 7c00h		; all checks passed, jump there

.fail:	mov ax, str_bootfail
	call printstr
.hang:	cli
	hlt
	jmp .hang


	; splash screen effect
splash:
	mov ax, 13h
	int 10h

	; setup ramdac colormap
	mov ax, pal
	shr ax, 4
	mov ds, ax
	xor ax, ax
	mov dx, 3c8h
	out dx, al
	inc dx
	xor bx, bx
.cmap_loop:
	mov al, [bx]
	shr al, 2
	out dx, al
	inc bx
	cmp bx, 768	; 256 * 3
	jnz .cmap_loop

	; decompress image
	mov ax, img
	shr ax, 4
	mov es, ax
	xor di, di
	mov ax, imgrle
	shr ax, 4
	mov ds, ax
	xor si, si
	mov cx, 64000
	call decode_rle

	; precalculate spawn points
	mov ax, es
	mov ds, ax	; decompressed image -> ds:bx
	xor bx, bx
	mov ax, spawn_pos
	shr ax, 4
	mov es, ax	; spawn_pos table segment -> es:dx
	xor edx, edx

	mov cx, 64000
.calcspawn_loop:
	mov al, [bx]
	test al, 0x80
	jz .notspawn
	mov [es:edx * 2], bx
	inc edx
.notspawn:
	inc bx
	dec cx
	jnz .calcspawn_loop
	; update num_spawn_pos
	xor ax, ax
	mov ds, ax
	mov [num_spawn_pos], edx

	mov ax, framebuf >> 4
	mov fs, ax		; fs will point to the off-screen framebuffer

	; effect main loop
.mainloop:
	mov cx, spawn_rate
.spawn:	call rand
	xor edx, edx
	div dword [num_spawn_pos]	; edx <- rand % num_spawn_pos
	mov bx, [es:edx * 2]		; grab one of the spawn positions

	; animate the spawn position
	xor ax, ax
	mov al, [frameno]
	mov bp, ax
	movsx ax, byte [bp + sintab]
	sar ax, 3
	add bx, ax

	mov byte [fs:bx], 0xff		; plot a pixel there
	dec cx
	jnz .spawn

	; blur the screen upwards
	mov ax, fs
	mov ds, ax	; let's use ds for this to avoid long instructions
	xor bx, bx	; use: pointer
	xor ax, ax	; use: pixel accum
	xor dx, dx	; use: second pixel
.blurloop:
	xor ax, ax
	mov al, [bx]
	mov dl, [bx + 320]
	add ax, dx
	mov dl, [bx + 319]
	add ax, dx
	mov dl, [bx + 321]
	add ax, dx
	mov dl, [bx + 640]
	add ax, dx
	xor dx, dx
	mov cx, 5
	div cx
	mov [bx], al

	inc bx
	cmp bx, 64000 - 640
	jnz .blurloop


	; wait until the start of vblank
.waitvblank:
	mov dx, 3dah
	in al, dx
	and al, 8
	jz .waitvblank

	; copy to screen
	push es
	mov ax, 0a000h
	mov es, ax
	xor di, di
	mov ax, fs
	mov ds, ax
	xor si, si
	mov ecx, 16000
	rep movsd
	pop es
	xor ax, ax
	mov ds, ax

	inc word [frameno]

	; check for keypress
	in al, 64h
	and al, 1
	jz .mainloop
	in al, 60h

.end:	mov ax, 3
	int 10h
	ret

	; decode RLE from ds:si to es:di, cx: number of decoded bytes (0 means 65536)
	; - high bit set for the repetition count, followed by a value byte to
	;   be repeated N times
	; - high bit not set for raw data that should be copied directly
decode_rle:
	mov al, [si]
	inc si
	mov bl, 1	; default to "copy once" for raw values
	test al, 0x80	; test the high bit to see if it's a count or a raw value
	jz .copy
	; it's a count, clear the high bit, and read the next byte for the value
	and al, 0x7f
	mov bl, al
	mov al, [si]
	inc si
.copy:	mov [es:di], al
	inc di
	dec cx		; decrement decoded bytes counter
	jz .end		; as soon as it reaches 0, bail
	dec bl
	jnz .copy
	jmp decode_rle
.end:	ret
	

waitkey:
	in al, 64h
	test al, 1
	jz waitkey
	in al, 60h
	ret

rand:
	mov eax, [randval]
	mul dword [randmul]
	add eax, 12345
	and eax, 0x7fffffff
	mov [randval], eax
	shr eax, 16
	ret

randmul dd 1103515245
randval dd 0ace1h


	; data
%include "lut.inc"

num_spawn_pos dd 0
frameno dw 0
	align 16
spawn_pos:
imgrle:	incbin "nuclear.rle"
	align 16
img:
pal:	incbin "fire.pal"

stage2_end:

; vi:set ft=nasm:
