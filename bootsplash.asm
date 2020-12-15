	org 7c00h
	bits 16

stacktop equ 7b00h
boot_driveno equ 7b00h	; 1 byte
stage2_size equ stage2_end - stage2_start

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
	mov ah, 2		; read sectors LBA call
	mov al, (stage2_size + 511) / 512  ; num sectors
	mov cx, 2		; ch: cylinder, cl: sector
	xor dx, dx		; dh: head
	mov dl, [boot_driveno]
	int 13h
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
str_booting db "Booting ...",0


	times 510-($-$$) db 0
	dw 0xaa55

	; start of the second stage
stage2_start:
	call splash

	xor ax, ax
	mov es, ax
	mov ds, ax

	mov ax, str_booting
	call printstr

	cli
.hang:	hlt
	jmp .hang

	; splash screen effect
splash:
	mov ax, 13h
	int 10h

	mov ax, 0a000h
	mov es, ax
	xor di, di

	mov ax, pic
	shr ax, 4
	mov ds, ax
	xor si, si

	mov cx, 64000
	call decode_rle

	call waitkey

	mov ax, 3
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

	; data
	align 16
pic:	incbin "nuclear.rle"

stage2_end:

; vi:set ft=nasm:
