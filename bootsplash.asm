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
	mov bx, ax
.loop:	mov al, [bx]
	inc bx
	test al, al
	jz .done
	mov ah, 0eh
	mov bx, 7
	int 10h
	jmp .loop
.done:	ret

str_load_fail db "Failed to load second stage!",0
str_foo db "Loaded 2nd stage boot loader",0


	times 510-($-$$) db 0
	dw 0xaa55

	; start of the second stage
stage2_start:
	mov ax, 13h
	int 10h

	mov ax, 0a000h
	mov es, ax
	xor di, di
	mov cx, 32000
	mov ax, 0505h
	rep stosw

	call waitkey

	mov ax, 3
	int 10h

	xor ax, ax
	mov es, ax

	mov ax, str_foo
	call printstr

.hang:	cli
	hlt
	jmp .hang

waitkey:
	in al, 64h
	test al, 1
	jz waitkey
	in al, 60h
	ret

stage2_end:

; vi:set ft=nasm:
