; bootsplash - bootable splash screen & chain-loader for IBM PC compatibles
; -------------------------------------------------------------------------
; Author: John Tsiombikas <nuclear@member.fsf.org>
; This code is public domain. No rights reserved.
; https://github.com/jtsiomb/bootsplash
; -------------------------------------------------------------------------
	org 7c00h
	bits 16

BOOT_DEV equ 80h

stacktop equ 7b00h
boot_driveno equ 7b00h		; 1 byte
load_driveno equ 7b01h		; 1 byte
num_floppies equ 7b02h		; 2 bytes
num_hd equ 7b04h		; 2 bytes
num_read_tries equ 7b06h	; 2 bytes
sect_pending equ 7b08h		; 2 bytes
sect_per_track equ 7b0ah	; 2 bytes
cur_head equ 7b0ch		; 2 bytes - current head
start_sect equ 7b0eh		; 2 bytes - start sector in track
destptr equ 7b10h		; 2 bytes - destination pointer
num_heads equ 7b12h		; 2 bytes - number of heads
cur_cyl equ 7b14h		; 2 bytes - current cylinder
stage2_size equ stage2_end - stage2_start

spawn_rate equ 512
framebuf equ 40000h

SC_1 equ 2	; scancode of key '1'

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

bios_param_block:
	jmp start	; 2 bytes
	nop		; 1 byte
	; start of BPB at offset 3
	db "BSPL 0.1"	; 03h: OEM ident, 8 bytes
	dw 512		; 0bh: bytes per sector
	db 1		; 0dh: sectors per cluster
	dw 1		; 0eh: reserved sectors (including boot record)
	db 2		; 10h: number of FATs
	dw 224		; 11h: number of dir entries
	dw 2880		; 13h: number of sectors in volume
	db 0fh		; 15h: media descriptor type (f = 3.5" HD floppy)
	dw 9		; 16h: number of sectors per FAT
	dw 18		; 18h: number of sectors per track
	dw 2		; 1ah: number of heads
	dd 0		; 1ch: number of hidden sectors
	dd 0		; 20h: high bits of sector count
	db 0		; 24h: drive number
	db 0		; 25h: winnt flags
	db 28h		; 26h: signature(?)
	dd 0		; 27h: volume serial number
	db "BOOT SPLASH"; 2bh: volume label, 11 bytes
	db "FAT12   "	; 36h: filesystem id, 8 bytes

start:
	cld
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov gs, ax
	mov fs, ax
	jmp 00:.setcs
.setcs:
	mov sp, stacktop
	mov [boot_driveno], dl

	; query sectors per track
	mov ah, 8	; get drive parameters call, dl already has the drive
	xor di, di
	int 13h
	jc .queryfail
	and cx, 3fh
	mov [sect_per_track], cx
	shr dx, 8
	inc dx
	mov [num_heads], dx
	jmp .querydone
.queryfail:
	; in case of failure, try 18 sectors per track, 2 heads
	mov word [sect_per_track], 18
	mov word [num_heads], 2
.querydone:

	; load the rest of the code at 7e00h
	mov ax, stage2_start
	shr ax, 4
	mov es, ax	; destination segment 7e0h to allow loading up to 64k
	mov word [destptr], 0
	mov word [sect_pending], (stage2_size + 511) / 512 + 1
	mov word [start_sect], 1	; start from sector 1 to skip boot sector
	mov word [cur_cyl], 0
	mov word [cur_head], 0

.rdloop:
	mov cx, [start_sect]
	mov ax, [sect_pending]
	sub ax, cx		; num_sect = pending - start_sect
	cmp ax, [sect_per_track]
	jbe .noadj
	mov ax, [sect_per_track]	; read max sect_per_track at a time
	sub ax, cx
.noadj:	push ax		; save how many sectors we're reading

	pusha
	call print_hex_word
	mov ax, str_rdtrack2
	call printstr
	mov ax, [cur_cyl]
	call print_hex_byte
	mov ax, str_rdtrack3
	call printstr
	mov ax, [cur_head]
	call print_hex_byte
	mov ax, str_rdtrack3
	call printstr
	mov ax, [start_sect]
	call print_hex_byte
	mov ax, str_newline
	call printstr
	popa

	mov ch, [cur_cyl]
	mov dh, [cur_head]
	mov bx, [destptr]

	inc cl			; sector numbers start from 1
	mov ah, 2		; read sectors is call 2
	mov dl, [boot_driveno]
	int 13h
	jc .fail
	; track read sucessfully
	mov word [start_sect], 0	; all subsequent tracks are whole
	mov ax, [cur_head]
	inc ax
	cmp ax, [num_heads]
	jnz .skip_cyl_adv
	xor ax, ax
	inc byte [cur_cyl]
.skip_cyl_adv:
	mov [cur_head], ax

	pop ax			; num_sect
	mov cx, ax
	shl cx, 9		; convert to bytes
	add [destptr], cx
	sub [sect_pending], ax
	jnz .rdloop

	; loaded sucessfully, reset es back to 0 and jump
	xor ax, ax
	mov es, ax
	jmp stage2_start

.fail:	add esp, 2	; clear num_sect off the stack
	dec word [num_read_tries]
	jz .abort

	; reset controller and retry
	xor ax, ax
	mov dl, [boot_driveno]
	int 13h
	jmp .rdloop

	; failed to load second sector
.abort:	xor ax, ax
	mov es, ax
	floppy_motor_off	; turn off floppy motor (if dl is < 80h)
	mov ax, str_load_fail
	call printstr
.hang:	hlt
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

print_hex_word:
	mov cx, 4	; 4 digits to print
	jmp print_n_hex_digits

print_hex_byte:
	mov cx, 2	; 2 digits to print
	mov ah, al	; move them in place

print_n_hex_digits:
	rol ax, 4
	mov dx, ax	; save ax, print_hex_digit destroys it
	call print_hex_digit
	mov ax, dx
	dec cx
	jnz print_n_hex_digits
	ret

print_hex_digit:
	mov bl, al
	and bx, 0fh
	mov al, [bx + .hexdig_tab]
	mov ah, 0eh
	mov bx, 7
	int 10h
	ret

.hexdig_tab:
	db "0123456789abcdef"

str_rdtrack2 db " from ",0
str_rdtrack3 db "/",0
str_load_fail db "Failed to load 2nd stage!",0
str_booting1 db "Booting system from drive ",0
str_booting2 db " ... ",0
str_bootfail db "failed!",0
str_newline db 13,10,0

	times 510-($-$$) db 0
bootsig dw 0xaa55

	; start of the second stage
stage2_start:
	floppy_motor_off
	mov ax, 13h
	int 10h

	call init_menu

	pushf
	cli
	call splash
	popf
	; save the scancode returned by splash
	xor ah, ah
	push ax

	mov ax, 3
	int 10h

	xor ax, ax
	mov es, ax
	mov ds, ax

	; initialize load_driveno to 80h (first hard disk)
	mov byte [load_driveno], 80h
	; check to see if the user pressed a key corresponding to a boot device
	; and set [load_driveno] accordingly (scancode was pushed as word)
	pop ax
	sub ax, SC_1
	js .end_devsel
	cmp ax, [num_floppies]
	jae .notfloppy
	mov [load_driveno], ax
	jmp .end_devsel
.notfloppy:
	sub ax, [num_floppies]
	cmp ax, [num_hd]
	jae .end_devsel
	or ax, 80h	; hard disk numbers have high bit set
	mov [load_driveno], ax
.end_devsel:

	mov ax, str_booting1
	call printstr
	mov ax, [load_driveno]
	call print_hex_byte
	mov ax, str_booting2
	call printstr

	; blank out the existing boot signature to really see if a boot sector
	; gets loaded correctly
	mov word [bootsig], 0
	mov word [num_read_tries], 3	; initialize number of retries to 3

	jmp .skip_rst	; don't reset the first time around
.retry_rst:
	xor ax, ax
	mov dx, [load_driveno]
	int 13h
.skip_rst:
	; load from [load_driveno] into 7c00h and jump
	mov bx, 7c00h
	mov ax, 0201h		; ah: call 2 (read sectors), al: count = 1
	mov cx, 1		; ch: cylinder 0, cl: sector 1
	mov dx, [load_driveno]	; dh: head 0, dl: boot device number
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

.fail:	dec word [num_read_tries]
	jnz .retry_rst
	mov ax, str_bootfail
	call printstr
.hang:	hlt
	jmp .hang


	; splash screen effect
splash:
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

	mov byte [fs:bx], 0f7h	; plot a pixel there (top 8 colors rsvd. for UI)
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
.invb:	in al, dx
	and al, 8
	jnz .invb
.offvb:	in al, dx
	and al, 8
	jz .offvb

	; copy to screen
	push es
	mov ax, 0a000h
	mov es, ax
	xor di, di
	mov ax, fs
	mov ds, ax
	xor si, si
	mov ecx, (64000 - 320 * 14) / 4
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

.end:	ret

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


init_menu:
	xor ax, ax
	mov [num_floppies], ax	; initialize both to 0
	mov [num_hd], ax

	mov es, ax	; ralf brown suggests pointing es:di to 0
	xor di, di	; to "guard against BIOS bugs"
	; get number of floppies
	mov ah, 8	; get drive params
	mov dl, 0	; floppy
	int 13h
	jc .no_floppies
	xor dh, dh
	mov [num_floppies], dx
.no_floppies:
	xor ax, ax
	mov es, ax
	xor di, di
	; get number of hard disks
	mov ah, 8
	mov dl, 80h
	int 13h
	jc .no_hd
	xor dh, dh
	mov [num_hd], dx
.no_hd:

	; clear the UI part of the framebuffer
	mov ax, 0a000h
	mov es, ax
	mov di, 64000 - 320 * 14
	mov ecx, 320 * 14 / 4
	xor eax, eax
	rep stosd

%macro blit_ui_button 1
	push ax
	push di
	push si
	mov bx, 14	; y
%%y:	mov ecx, 32/4	; x
	rep movsd
	add di, 320 - 32
	dec bx
	jnz %%y
	mov bp, sp
	mov si, [bp]
	mov di, [bp + 2]
	add di, 3 * 320 + 4
	add ax, %1
	call draw_num
	pop si
	pop di
	pop ax
%endmacro

	; draw UI buttons
	mov di, 64000 - 320 * 14
	mov si, uigfx		; floppy icon
	xor ax, ax
.draw_floppies:
	cmp ax, [num_floppies]
	jz .done_floppies
	inc ax
	blit_ui_button 0
	add di, 34		; leave a gap between buttons
	jmp .draw_floppies
.done_floppies:
	mov si, uigfx + 32 * 14	; hard disk icon
	xor ax, ax
.draw_harddisks:
	cmp ax, [num_hd]
	jz .done_harddisks
	inc ax
	blit_ui_button [num_floppies]
	add di, 34
	jmp .draw_harddisks
.done_harddisks:

	xor ax, ax
	mov es, ax	; zero es again
	ret

draw_num:
	mov bp, sp
	mov cx, 10
.div:	xor dx, dx
	div cx
	push dx
	and ax, ax
	jnz .div
.draw:	cmp sp, bp
	jz .done
	pop ax
	shl ax, 3
	add ax, font0
	mov si, ax
	call blit1bpp	; blit from ds:si -> a000h:di converting 1bpp -> 8bpp
	add di, 8
	jmp .draw
.done:	ret

blit1bpp:
	push es
	push di
	mov ax, 0a000h
	mov es, ax

	mov dx, 8
.row:	mov cx, 8
	xor ax, ax
	lodsb
	mov ah, al
.col:	rol ah, 1
	mov al, 0ffh
	test ah, 1
	jnz .skip0
	xor al, al
.skip0:	stosb
	dec cx
	jnz .col
	add di, 320 - 8
	dec dx
	jnz .row

	pop di
	pop es
	ret


	; data
%include "numfont.inc"
%include "lut.inc"

uigfx:	incbin "ui.img"

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
