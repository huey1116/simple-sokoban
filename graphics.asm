; sets text mode
setTextMode:
	push bx
	push ax

	mov ah, 0
	mov al, 3
	int 10h

	pop ax
	pop bx
	ret

; sets video mode 4
setVideoMode:
	push bx
	push ax

	mov ah, 0
	mov al, 4
	int 10h
	mov ah, 11
	mov bh, 1
	mov bl, 1
	int 10h

	pop ax
	pop bx
	ret

; sets ES:DI to world position
; BH,BL: (x,y) position
getWorldPos:
	push bx
	push ax

	shl bh, 1
	shl bl, 3

	mov ah, 0
	mov al, bh
	mov di, ax

	mov al, bl
	mov bx, 40
	mul bx
	add di, ax
	mov ax, 0b800h
	mov es, ax

	pop ax
	pop bx
	ret

; advances ES:DI by one line
nextScreenLine:
	push ax
	
	mov ax, di
	and ax, 2000h
	mov ax, di
	jz .nextScreenLineEven
	add ax, 80
.nextScreenLineEven:
	xor ax, 2000h
	mov di, ax

	pop ax
	ret

; draws sprite at (x,y) position (in world coords)
; DS:SI : sprite
; BH,BL : (x,y)
drawSpriteAt:
	push si
	push di
	push cx
	push dx
	
	call getWorldPos

	mov ch, 2
	mov cl, 8
	.drawX:
		push di
	.drawXloop:
		movsb
		dec ch
		jnz .drawXloop

	mov ch, 2
	pop di
	call nextScreenLine
	dec cl
	jnz .drawX

	pop dx
	pop cx
	pop di
	pop si
	ret
