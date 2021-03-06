IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

VM EQU 13h				;video mode
WHITE EQU 0Fh 			;white (row: 0, col: F) using default colour palette
VMEMADR EQU 0A0000h		;video memory address
SCRWIDTH EQU 320		;screen witdth
SCRHEIGHT EQU 200		;screen height
BACKGROUNDCOL EQU 00h	;background color (row: 0, col: 0)

CODESEG

;--------------------------------------------------------
;STRUC
;--------------------------------------------------------

;2D vector (coördinate)

STRUC vec
	x dd ?
	y dd ?
ENDS vec

;axis aligned bounding box (no rotation)
;min: top left corner, max: bottom right corner

STRUC AABB
	min	vec <>
	max vec <>
ENDS AABB

;rectangle

STRUC rect
	box AABB <>
	velocity vec <>
	mass dd ?
ENDS rect

;manifold
;collection of points (intersection of 2 rectangles)
;used to compute penetration and a normal vector to later compute impulse resolution with

STRUC manifold
	rect1 rect <>
	rect2 rect <>
	penetration dd ?
	normal vec <>
ENDS manifold

;--------------------------------------------------------
;SETUP PROCEDURES
;--------------------------------------------------------

;set begin values for AABB struct in a rectangle

PROC initRectangle
	ARG 	@@rectPtr:dword, @@xmin:dword, @@ymin:dword, @@xmax:dword, @@ymax:dword, @@velx:dword, @@vely:dword, @@mass:dword
	USES 	eax, ebx, ecx, edx, edi

	mov eax, [rectNum]
	inc eax
	mov [rectNum], eax
	mov eax, [@@rectPtr]
initAABB:
	mov ebx, [@@xmin]
	mov ecx, [@@ymin]
	mov edx, [@@xmax]
	mov edi, [@@ymax]
	mov [(rect eax).box.min.x], ebx
	mov [(rect eax).box.min.y], ecx
	mov [(rect eax).box.max.x], edx
	mov [(rect eax).box.max.y], edi
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
	add [(rect eax).box.min.x], ecx
	add [(rect eax).box.min.y], edx
	add [(rect eax).box.max.x], ecx
	add [(rect eax).box.max.y], edx
	call drawRectangle, eax, WHITE
	ret
ENDP moveRectangle

;map moveRectangle on rectLst

PROC moveAllRects
	USES	eax, ecx

	mov ecx, [rectNum]
	mov eax, 0
keepMoving:
	call moveRectangle, [rectLst + 4*eax]
	inc eax
	loop keepMoving
doneMoving:
	ret
ENDP moveAllRects

;check if a rectangle hit a border
;if so, bounce off

PROC checkIfHit
	ARG 	@@rect1Ptr:dword
	USES 	eax, ebx, ecx, edx

	mov edx, [@@rect1Ptr]
	;check if hit borders
checkHorizontal:
	mov eax, [(rect edx).box.min.x]
	add eax, [(rect edx).velocity.x]
	cmp eax, 0
	jle hitLeftBorder
	mov eax, [(rect edx).box.max.x]
	add eax, [(rect edx).velocity.x]
	cmp eax, SCRWIDTH
	jge hitRightBorder
	jmp checkVertical
hitLeftBorder:
hitRightBorder:
	mov eax, [(rect edx).velocity.x]
	imul eax, -1
	mov [(rect edx).velocity.x], eax
checkVertical:
	mov eax, [(rect edx).box.min.y]
	add eax, [(rect edx).velocity.y]
	cmp eax, 0
	jle hitTopBorder
	mov eax, [(rect edx).box.max.y]
	add eax, [(rect edx).velocity.y]
	cmp eax, SCRHEIGHT
	jge hitBottomBorder
	jmp noBorder
hitTopBorder:
hitBottomBorder:
	mov eax, [(rect edx).velocity.y]
	imul eax, -1
	mov [(rect edx).velocity.y], eax
noBorder:
	ret
ENDP checkIfHit

;map checkIfHit on rectLst

PROC checkAllIfHit
	USES	eax, ecx

	mov ecx, [rectNum]
	mov eax, 0
keepChecking:
	call checkIfHit, [rectLst + 4*eax]
	inc eax
	loop keepChecking
doneChecking:
	ret
ENDP checkAllIfHit

;collision detection
;using the separating axis theorem:
;if you are able to draw a line to separate two convex polygons, then they do not collide

PROC checkCollision
	ARG 	@@rect1Ptr:dword, @@rect2Ptr:dword
	USES eax, ebx, edx, ecx

	mov eax, [@@rect1Ptr]
	mov ebx, [@@rect2Ptr]

	mov ecx, [(rect ebx).box.min.x]
	mov edx, [(rect eax).box.max.x]
	cmp edx, ecx
	jle noIntersection
	mov ecx, [(rect ebx).box.max.x]
	mov edx, [(rect eax).box.min.x]
	cmp edx, ecx
	jge noIntersection
	mov ecx, [(rect ebx).box.min.y]
	mov edx, [(rect eax).box.max.y]
	cmp edx, ecx
	jle noIntersection
	mov ecx, [(rect ebx).box.max.y]
	mov edx, [(rect eax).box.min.y]
	cmp edx, ecx
	jge noIntersection
	jmp intersection
noIntersection:
	ret
intersection:
	mov [(rect eax).velocity.x], 0
	mov [(rect eax).velocity.y], 0
	mov [(rect ebx).velocity.x], 0
	mov [(rect ebx).velocity.y], 0
	ret
ENDP checkCollision

;map checkCollision on rectLst

PROC checkAllCollisions
	USES 	eax, ebx, ecx, edx

	mov eax, 0
	mov ebx, 1
	mov ecx, [rectNum]
	sub ecx, 1
@@outerLoop:
	push ecx
	mov ecx, [rectNum]
	sub ecx, ebx
@@innerLoop:
	call checkCollision, [rectLst + 4*eax], [rectLst + 4*ebx]
	inc ebx
	loop @@innerLoop
	pop ecx
	inc eax
	mov ebx, eax
	inc ebx
	loop @@outerLoop
stopCheckingLoop:
	ret
ENDP checkAllCollisions

;impulse resolution

PROC impulseResolution
	ARG 	@@rect1Ptr:dword, @@rect2Ptr:dword
	USES 	eax, ebx, ecx, edx



	ret
ENDP impulseResolution

;calculate manifold

PROC AABBvsAABB
	ARG		@@manifoldPtr:dword
	USES 	eax, ebx, ecx, edx

	mov ecx, [@@manifoldPtr]
	mov eax, [(manifold ecx).rect1.box.min.x]
	mov ebx, [(manifold ecx).rect2.box.min.x]
	sub ebx, eax
	push ebx
	mov eax, [(manifold ecx).rect1.box.min.y]
	mov ebx, [(manifold ecx).rect2.box.min.y]
	sub ebx, eax
	pop eax
	vecAB vec <> ;vector from A to B
	mov [vecAB.x], eax
	mov [vecAB.y], ebx

	mov ebx, [(manifold ecx).rect1.box.max.x]
	sub ebx, eax
	mov eax, ebx
	mov ebx, 2
	xor edx, edx
	div ebx
	push eax ;result of half extent along x axis rect1 in eax

	mov ebx, [(manifold ecx).rect2.box.max.x]
	mov eax, [(manifold ecx).rect2.box.min.x]
	sub ebx, eax
	mov eax, ebx
	mov ebx, 2
	xor edx, edx
	div ebx ;result of half extent along x axis rect2 in eax

	pop ebx
	add eax, ebx ;added half extents
	mov ebx, [vecAB.x]
	cmp ebx, 0
	jg @@alreadyPositive
	imul ebx, -1
@@alreadyPositive:
	sub eax, ebx ;x overlap
	cmp eax, 0
	jle @@noOverlap

@@noOverlap:
	ret
ENDP AABBvsAABB

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
	mov eax, [(rect ebx).box.min.y]
	mov edx, SCRWIDTH
	mul edx
	add	eax, [(rect ebx).box.min.x]

	; Compute top left corner address
	mov edi, offset screenBuffer
	add edi, eax
	
	; Plot the top horizontal edge.
	mov edx, [(rect ebx).box.max.x]
	sub edx, [(rect ebx).box.min.x] ; store width in edx for later reuse
	mov	ecx, edx
	mov	al, [@@col]
	rep stosb
	sub edi, edx		; reset edi to left-top corner
	
	; plot both vertical edges
	mov ecx, [(rect ebx).box.max.y]
	sub ecx, [(rect ebx).box.min.y]
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

;start game status
;create structs and initialize shapes

PROC startGameStatus
	USES 	eax, ebx, ecx

	square rect <>
	balk rect <>
	paal rect <>
	squareBalkMan manifold <>
	mov [rectLst], offset square
	call initRectangle, offset square, 0, 10, 10, 20, 2, 1, 10
	mov ecx, 1
	mov [rectLst + 4*ecx], offset balk
	call initRectangle, offset balk, SCRWIDTH - 20, 10, SCRWIDTH, 15, -1, 2, 10
	inc ecx
	mov [rectLst + 4*ecx], offset paal
	call initRectangle, offset paal, SCRWIDTH/2, SCRHEIGHT/2, SCRWIDTH/2 + 5, SCRHEIGHT/2 + 20, 1, 2

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

	call moveAllRects
	call checkAllIfHit
	call checkAllCollisions

	ret
ENDP updateGameStatus

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
;MAIN
;--------------------------------------------------------

PROC main

    sti
    cld

    push ds
    pop es

    call setVideoMode, VM
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
	rectLst 		dd 64 dup(?), '$'
	rectNum 		dd 0

STACK 100h

END main