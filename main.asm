bits 16
org 100h

jmp init ; pretty massive jump innit

; god i hate crlf
welcomemsg: db "hello!! :) this program is a very boring sokoban clone.", 0x0d, 0x0a
			db "the controls are:", 0x0a, 0x0d
			db "Q: quit", 0x0a, 0x0d
			db "E: advance to next level, resets map if not solved", 0x0a, 0x0d
			db "you move with the arrow keys.", 0x0a, 0x0d
			db "press any key to continue :D$"


%include "graphics.asm"
%include "tiles.asm"
%include "levels.asm"


%define BOXTILE 0x10
%define WALLTILE 0x33
%define GOALTILE 0x02
%define FLOORTILE 0x00
%define HAPPYTILE 0x12
%define LVLBUFSIZE 1004
%define MAPWIDTH 40
%define MAPHEIGHT 25


init:
	mov dx, welcomemsg
	mov ah, 0x09
	int 21h
	mov ah, 0
	int 16h
	
	call setVideoMode
	call main

; selects sprite from tile ID
; AL: tile ID
; result:
; DS:SI now pointing to appropriate sprite
selectSprite:
	push ax

	cmp al, FLOORTILE 
	je .selectFloor

	cmp al, WALLTILE
	je .selectWall

	cmp al, BOXTILE
	je .selectBox

	cmp al, GOALTILE
	je .selectGoal

	cmp al, HAPPYTILE
	je .selectGoalHappy

	.selectFloor:
		mov si, tile_floor
		jmp .selectDone

	.selectWall:
		mov si, tile_wall
		jmp .selectDone

	.selectBox:
		mov si, tile_box
		jmp .selectDone

	.selectGoal:
		mov si, tile_goal
		jmp .selectDone

	.selectGoalHappy:
		mov si, tile_goalhappy
		jmp .selectDone

.selectDone:
	pop ax
	ret

; gets number of tiles in map (width*height)
; DS:SI points to map
; result:
; AX now contains number of tiles in map
; DS:SI unchanged
getMapSize:
	push si
	push bx

	mov bx, 0

	lodsw

	mov bl, ah
	mov ah, 0
	mul bx
	
	pop bx
	pop si
	ret

; gets map width and height 
; DS:SI points to map
; result:
; AX now contains the map dimensions (AH = width, AL = height)
; DS:SI unchanged
getMapDimensions:
	push si

	lodsw

	pop si
	ret

; point DS:SI to specific map tile
; BH,BL: x,y
; result:
; DS:SI advanced to tile at (x,y)
getTileAt:
	push cx
	push bx
	push ax

	lodsw ; get map size (AH = Width, AL = Height)

	mov cx, bx
	mov al, ah
	mov ah, 0
	mul bl ; AX = y * width
	
	mov bl, bh
	mov bh, 0
	add ax, bx ; AX = y * width + x
	add si, ax 

	pop ax
	pop bx
	pop cx
	ret

; gets tile at specific location
; BH,BL: x,y
; result:
; AL now contains the tile ID
; DS:SI unchanged
getTileCodeAt:
	push si

	call getTileAt
	lodsb 

	pop si
	ret

; loads map into the map buffer
; DS:SI : map data
; result:
; DS:SI now located at map buffer
; buffer populated with da map :)
loadMap:
	push es
	push di
	push ax
	push bx

	mov [currmapaddr], si

	mov bx, 0
	mov ax, ds
	mov es, ax
	mov di, mapbuffer

	call getMapSize

	add ax, 4

	.loadMapLoop:
		movsb
		dec ax
		jnz .loadMapLoop

	mov [nextmapaddr], si
	mov si, mapbuffer

	pop bx
	pop ax
	pop di
	pop es
	ret

; oh gee i wonder what this does
; DS:SI : map buffer
clearMapBuffer:
	push si
	push cx

	mov cx, LVLBUFSIZE/2
	clearLoop:
		mov word[ds:si], 0x00
		dec cx
		jnz clearLoop

	pop si
	pop cx
	ret

; basically clears the screen
; DS:SI : map buffer
clearMapScreen:
	push cx
	push bx
	push ax
	push si

	call getMapDimensions
	mov cx, ax

	mov bx, 0
	mov si, tile_floor
	.drawLineLoop:
		call drawSpriteAt
		inc bh
		dec ch
		jnz .drawLineLoop

	mov ch, ah
	mov bh, 0
	inc bl
	dec cl
	jnz .drawLineLoop

	pop si
	pop ax
	pop bx
	pop cx
	ret

; renders tile from map at a specific (x,y)
; BH,BL : (x,y) coordinate
; DS:SI : map buffer
drawMapTileAt:
	push si
	push ax

	call getTileAt
	lodsb
	call selectSprite
	call drawSpriteAt

	pop ax
	pop si
	ret

; renders map (crazy right)
; DS:SI : map buffer
renderMap:
	push cx
	push bx
	push ax
	push si

	call getMapDimensions
	mov cx, ax

	mov bx, 0

	.drawLineLoop:
		call drawMapTileAt
		inc bh
		dec ch
		jnz .drawLineLoop

	mov ch, ah
	mov bh, 0
	inc bl
	dec cl
	jnz .drawLineLoop

	pop si
	pop ax
	pop bx
	pop cx
	ret

; gets starting coordinates of player
; result:
; sets DH,DL to player's starting (x,y)
getPlayerStartCoords:
	push si
	push ax

	call getMapSize
	add ax, 2

	add si, ax
	lodsw
	mov dx, ax

	pop ax
	pop si
	ret

; renders player
; DH,DL : player's (x,y)
drawPlayer:
	push si
	push bx
	
	mov si, tile_player
	mov bx, dx
	call drawSpriteAt

	pop bx
	pop si
	ret

; removes box from map
; BH,BL : (x,y)
removeBox:
	push si
	call getTileAt
	sub byte[ds:si], BOXTILE
	pop si
	ret

; create box in map
; BH,BL : (x,y)
createBox:
	push si
	call getTileAt
	add byte[ds:si], BOXTILE
	pop si
	ret

; checks if map is solved
; result:
; AX = 0 if the map is solved, 1 otherwise
checkSolve:
	push si
	push bx
	push cx
	push dx

	call getMapDimensions
	mov bx, 0
	mov cx, ax
	mov dx, ax
	.checkSolveLoop:
		call getTileCodeAt
		cmp al, BOXTILE
		je .notsolved
		inc bh
		dec ch
		jnz .checkSolveLoop

	mov bh, 0
	mov ch, dh
	inc bl
	dec cl
	jnz .checkSolveLoop

	mov ax, 0
	jmp .done
	.notsolved:
		mov ax, 1
	.done:
		pop dx
		pop cx
		pop bx
		pop si
		ret

; finally, main.
main: 
	mov si, map_list
	call loadMap
	call renderMap
	call getPlayerStartCoords

gameLoop:
	call drawPlayer

	.input:
		mov ah, 0
		int 16h

		cmp al, 'q'
		je exit
		cmp ah, 0x48
		je .moveUp
		cmp ah, 0x4B
		je .moveLeft
		cmp ah, 0x50
		je .moveDown
		cmp ah, 0x4D
		je .moveRight
		cmp al, 'e'
		je .verify

		jmp gameLoop


	.verify:
		call checkSolve
		call clearMapScreen
		or ax, ax
		jz .loadNextMap

		call clearMapBuffer
		mov si, [currmapaddr]
		call loadMap
		call renderMap
		call getPlayerStartCoords
		jmp gameLoop

		.loadNextMap:
			call clearMapBuffer
			mov si, [nextmapaddr]
			cmp byte[ds:si], 0xff
			je endGame
			call loadMap
			call renderMap
			call getPlayerStartCoords
			jmp gameLoop


	.moveUp:
		mov bx, dx
		or dl, dl
		jz gameLoop

		dec bl
		call getTileCodeAt
		cmp al, WALLTILE
		je gameLoop
		cmp al, BOXTILE
		jge .moveBoxUp
		jmp .moveUpDone
		
	.moveLeft:
		mov bx, dx
		or dh, dh
		jz gameLoop

		dec bh
		call getTileCodeAt
		cmp al, WALLTILE
		je gameLoop
		cmp al, BOXTILE
		jge .moveBoxLeft
		jmp .moveLeftDone

	.moveDown:
		mov bx, dx
		cmp dl, MAPHEIGHT-1
		je gameLoop

		inc bl
		call getTileCodeAt
		cmp al, WALLTILE
		je gameLoop
		cmp al, BOXTILE
		jge .moveBoxDown
		jmp .moveDownDone

	.moveRight:
		mov bx, dx
		cmp dh, MAPWIDTH-1
		je gameLoop

		inc bh
		call getTileCodeAt
		cmp al, WALLTILE
		je gameLoop
		cmp al, BOXTILE
		jge .moveBoxRight
		jmp .moveRightDone


	.moveUpDone:
		inc bl
		call drawMapTileAt
		dec dl
		jmp gameLoop

	.moveLeftDone:
		inc bh
		call drawMapTileAt
		dec dh
		jmp gameLoop

	.moveDownDone:
		dec bl
		call drawMapTileAt
		inc dl
		jmp gameLoop

	.moveRightDone:
		dec bh
		call drawMapTileAt
		inc dh
		jmp gameLoop


	.moveBoxUp:
		dec bl
		call getTileCodeAt
		cmp al, WALLTILE
		je .moveBoxUpFail
		cmp al, BOXTILE
		jge .moveBoxUpFail

		call createBox
		call drawMapTileAt

		inc bl
		call removeBox
		call drawMapTileAt

		jmp .moveUpDone

		.moveBoxUpFail:
			inc bl
			inc bl
			jmp gameLoop

	.moveBoxLeft:
		dec bh
		call getTileCodeAt
		cmp al, WALLTILE
		je .moveBoxLeftFail
		cmp al, BOXTILE
		jge .moveBoxLeftFail
		
		call createBox
		call drawMapTileAt

		inc bh
		call removeBox
		call drawMapTileAt

		jmp .moveLeftDone

		.moveBoxLeftFail:
			inc bh
			inc bh
			jmp gameLoop

	.moveBoxDown:
		inc bl
		call getTileCodeAt
		cmp al, WALLTILE
		je .moveBoxDownFail
		cmp al, BOXTILE
		jge .moveBoxDownFail

		call createBox
		call drawMapTileAt

		dec bl
		call removeBox
		call drawMapTileAt

		jmp .moveDownDone

		.moveBoxDownFail:
			dec bl
			dec bl
			jmp gameLoop


	.moveBoxRight:
		inc bh
		call getTileCodeAt
		cmp al, WALLTILE
		je .moveBoxRightFail
		cmp al, BOXTILE
		jge .moveBoxRightFail

		call createBox
		call drawMapTileAt

		dec bh
		call removeBox
		call drawMapTileAt

		jmp .moveRightDone

		.moveBoxRightFail:
			dec bh
			dec bh
			jmp gameLoop

congratmsg: db "nice!$"
endGame:
	call setTextMode
	mov dx, congratmsg
	mov ah, 9
	mov al, 0
	int 21h
	int 20h

exit:
	call setTextMode
	int 20h
