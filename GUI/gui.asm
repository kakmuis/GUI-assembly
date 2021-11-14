IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

WHITE EQU 0Fh 			; white
VMEMADR EQU 0A0000h		; video memory address
SCRWIDTH EQU 320		; screen witdth
SCRHEIGHT EQU 200		; screen height
BACKGROUNDCOL EQU 0		; background color	 

CODESEG

;--------------------------------------------------------
;STRUC
;--------------------------------------------------------

STRUC vec
	x dd ?
	y dd ?
ENDS vec

;min: top left corner, max: bottom right corner

STRUC AABB
	min	vec <>
	max vec <>
ENDS AABB

STRUC rect
	boundingBox AABB <>
	velocity vec <>
	mass dd ?
ENDS rect

;set begin values for AABB struct

PROC initRectangle
	ARG 	@@rectPtr:dword, @@xmin:dword, @@ymin:dword, @@xmax:dword, @@ymax:dword, @@velx:dword, @@vely:dword, @@mass:dword
	USES 	eax, ebx, ecx, edx, edi

	mov eax, [@@rectPtr]
initAABB:
	mov ebx, [@@xmin]
	mov ecx, [@@ymin]
	mov edx, [@@xmax]
	mov edi, [@@ymax]
	mov [(rect eax).boundingBox.min.x], ecx
	mov [(rect eax).boundingBox.min.y], ebx
	mov [(rect eax).boundingBox.max.x], edx
	mov [(rect eax).boundingBox.max.y], edi
initVelocity:
	mov ebx, [@@velx]
	mov ecx, [@@vely]
	mov [(rect eax).velocity.x], ebx
	mov [(rect eax).velocity.y], ecx
initMass:
	mov ebx, [@@mass]
	mov [(rect eax).mass], ebx

	ret
ENDP initRectangle

;--------------------------------------------------------
;GAMELOOP PROCEDURES
;--------------------------------------------------------

;set video mode (text: 03h or VGA: 13h)

PROC setVideoMode
	ARG     @@VM:byte
	USES 	eax

	movzx ax, [@@VM]
	int 10h

	ret
ENDP setVideoMode

;setup function

PROC startGameStatus
	USES 	eax, ebx, ecx

	square rect <>
	balk rect <>
	call initRectangle, offset square, 10, 10, 20, 20, 1, 0, 10
	;call initRectangle, offset balk, 30, 10, 40, 20, 0, 0, 10
	call drawRectangle, offset square, WHITE
	;call drawRectangle, offset balk, WHITE

	ret
ENDP startGameStatus

;wait until vertical blank interval is completed

PROC waitForVBI
	USES 	edx, eax

	mov dx, 03DAh
@@waitForEnd:
	in al, dx
	and al, 8
	jnz @@waitForEnd
@@waitForBegin:
	in al, dx
	and al, 8
	jz @@waitForBegin
	ret
ENDP waitForVBI

;copy buffer to actual video memory

PROC updateVideoBuffer
	USES 	esi, edi, ecx

	cld
	mov esi, offset screenBuffer
	mov edi, 0A0000h
	mov ecx, 64000/4
	rep movsd

	ret
ENDP

;if esc is pressed, terminate process

PROC handleInput
	USES 	eax

	mov ah, 01h
	int 16h
	jz @@noKeyPressed

@@keyPressed:
	mov ah, 00h
	int 16h
	cmp ah, 1h
	jz @@escPressed
	ret

@@escPressed:
	call terminateProcess
	ret

@@noKeyPressed:
	ret

ENDP handleInput

;update loop

PROC updateGameStatus
	
	call moveRectangle, offset square
	;call moveRectangle, offset balk
	;call checkIfHit, offset square, offset balk
	;call checkIfHit, offset balk

	ret
ENDP updateGameStatus

;check if rect hit border

PROC checkIfHit
	ARG 	@@rect1Ptr:dword, @@rect2Ptr:dword
	USES 	eax, ebx, ecx

	mov ebx, [@@rect1Ptr]
	mov ecx, [@@rect2Ptr]
	;check if hit borders
checkHorizontal:
	cmp [(rect ebx).boundingBox.min.x], 0
	jle hitLeftBorder
	cmp [(rect ebx).boundingBox.max.x], SCRWIDTH
	jge hitRightBorder
	jmp checkVertical
hitLeftBorder:
hitRightBorder:
	mov eax, [(rect ebx).velocity.x]
	imul eax, -1
	mov [(rect ebx).velocity.x], eax
checkVertical:
	cmp [(rect ebx).boundingBox.min.y], 0	
	jle hitTopBorder
	cmp [(rect ebx).boundingBox.max.y], SCRHEIGHT
	jge hitBottomBorder
	jmp noBorder
hitTopBorder:
hitBottomBorder:
	mov eax, [(rect ebx).velocity.y]
	imul eax, -1
	mov [(rect ebx).velocity.y], eax
noBorder:
	;check if hit other rects
	call checkCollision, ebx, ecx
	cmp eax, 1
	jnz noCollision
	mov [(rect ebx).velocity.x], 0
	mov [(rect ebx).velocity.y], 0
noCollision:
	ret
ENDP checkIfHit

;collision detection

PROC checkCollision
	ARG 	@@rect1Ptr:dword, @@rect2Ptr:dword
	USES ebx, ecx, edx ;res in eax

	mov ebx, [@@rect1Ptr]
	mov ecx, [@@rect2Ptr]

	mov edx, [(rect ecx).boundingBox.min.x]
	cmp [(rect ebx).boundingBox.max.x], edx
	jl noIntersection
	mov edx, [(rect ecx).boundingBox.max.x]
	cmp [(rect ebx).boundingBox.min.x], edx
	jg noIntersection
	mov edx, [(rect ecx).boundingBox.min.y]
	cmp [(rect ebx).boundingBox.max.y], edx
	jl noIntersection
	mov edx, [(rect ecx).boundingBox.max.y]
	cmp [(rect ebx).boundingBox.min.y], edx
	jg noIntersection
	jmp intersection
noIntersection:
	mov eax, 0
	ret
intersection:
	mov eax, 1
	ret
ENDP checkCollision

;wait until user enters a key

PROC waitForSpecificKeystroke
	ARG 	@@key:byte
	USES 	eax

waitForKeystroke:
	mov	ah, 00h	
	int	16h
	cmp	al, [@@key]
	jne	waitForKeystroke
	ret
ENDP waitForSpecificKeystroke

;set video mode to text mode

PROC terminateProcess
	USES    eax

	call setVideoMode, 03h
	mov	ax, 04C00h
	int 21h

	ret
ENDP terminateProcess

;--------------------------------------------------------
;DRAWING PROCEDURES
;--------------------------------------------------------

;Change color of a single pixel, given a coördinate (x: [0; 320], y: [0; 200]) and a color [00h; FFh]

PROC setPixel
	ARG 	@@x:dword, @@y:dword, @@col:byte
	USES 	edi, eax, ecx, edx

	mov eax, [@@y]
	mov edx, SCRWIDTH
	mul edx				;calculate row offset
	add	eax, [@@x]		;calculate column offset
	mov edi, offset screenBuffer
	add edi, eax		;calculate coordinate idx
    mov al, [@@col]
    stosb				;store color in screenBuffer at idx edi

	ret
ENDP setPixel

;draw AABB struc, given a color

PROC drawRectangle
	ARG 	@@rectPtr:dword, @@col:byte
	USES 	eax, ebx, ecx, edx, edi ; note: MUL uses edx!

	; Compute the index of the rectangle's top left corner
	mov ebx, [@@rectPtr]
	mov eax, [(rect ebx).boundingBox.min.y]
	mov edx, SCRWIDTH
	mul edx
	add	eax, [(rect ebx).boundingBox.min.x]

	; Compute top left corner address
	mov edi, offset screenBuffer
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [(rect ebx).boundingBox.max.x]
	sub edx, [(rect ebx).boundingBox.min.x] ; store width in edx for later reuse
	mov	ecx, edx
	mov	al, [@@col]
	rep stosb
	sub edi, edx		; reset edi to left-top corner
	
	; plot both vertical edges
	mov ecx, [(rect ebx).boundingBox.max.y]
	sub ecx, [(rect ebx).boundingBox.min.y]
	@@vertLoop:
		mov	[edi], al		; left edge
		mov	[edi+edx-1], al	; right edge
		add	edi, SCRWIDTH
		loop @@vertLoop
	; edi should point at the bottom-left corner now
	sub edi, SCRWIDTH

	; Plot the bottom horizontal edge.
	mov	ecx, edx
	rep stosb
	ret
ENDP drawRectangle

;--------------------------------------------------------
;PHYSICS
;--------------------------------------------------------

;move a rectangle (draw same rectangle in black, move and draw again)

PROC moveRectangle
	ARG		@@rectPtr:dword
	USES 	eax, ebx, ecx, edx, edi

	mov eax, [@@rectPtr]
	call drawRectangle, eax, BACKGROUNDCOL
	mov ecx, [(rect eax).velocity.x]
	mov edx, [(rect eax).velocity.y]
	add [(rect eax).boundingBox.min.x], ecx
	add [(rect eax).boundingBox.min.y], edx
	add [(rect eax).boundingBox.max.x], ecx
	add [(rect eax).boundingBox.max.y], edx
	call drawRectangle, eax, WHITE
	ret
ENDP moveRectangle

;--------------------------------------------------------
;MAIN
;--------------------------------------------------------

PROC main

    sti
    cld

    push ds
    pop es

    call setVideoMode, 13h
	call startGameStatus

gameLoop:
	call waitForVBI
	call updateVideoBuffer
	call handleInput
	call updateGameStatus
	jnz gameLoop
dead:

ENDP main

;--------------------------------------------------------
;DATA
;--------------------------------------------------------

DATASEG

	screenBuffer 	db 64000 dup(0), '$'

STACK 100h

END main