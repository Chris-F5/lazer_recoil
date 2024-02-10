org 100h

section .text

mov ax, 0a000h
add ax, ax
mov [back_buffer_segment], ax

jmp start

vsync:
	push ax
	push dx

	mov dx, 03dah ; vga input status register
_wait_retrace_interval_end:
	in al, dx
	test al, 08h
	jnz _wait_retrace_interval_end
_wait_retrace_interval:
	in al, dx
	test al, 08h
	jz _wait_retrace_interval

	pop dx
	pop ax
	ret
clear:
	push ax
	push cx
	push es

	mov ax, [back_buffer_segment]
	mov es, ax
	mov di, 0
	mov ax, 1313h
	mov cx, 320*200/2
	rep stosw

	pop es
	pop cx
	pop ax
	ret

reflect_theta:
	push bp
	mov bp, sp
	; [bp+6] theta
	; [bp+4] normal
	push ax
	push bx
	push cx

	mov ax, [bp+4]
	add ax, ax ; ax = normal * 2
	add ax, 256
	add ax, 256
	add ax, 256
	mov bx, [bp+6]
	add bx, 128
	sub ax, bx ; ax = normal*2 - theta

_theta_over:
	sub ax, 256
	cmp ax, 255
	jg _theta_over

	mov [bp+6], ax

	pop cx
	pop bx
	pop ax
	pop bp
	ret

intersect_wall:
	push bp
	mov bp, sp
	; [bp+8] x
	; [bp+6] y
	; [bp+4] wall ptr
	sub sp, 14
	; [bp- 2] x0
	; [bp- 4] x1
	; [bp- 6] y0
	; [bp- 8] y1
	; [bp-10] xc
	; [bp-12] yc
	; [bp-14] c
	push ax
	push bx
	push cx

	mov bx, [bp+4]
	mov ax, [bx]
	mov [bp-2], ax ; x0
	add bx, 2
	mov ax, [bx]
	mov [bp-4], ax ; x1
	add bx, 2
	mov ax, [bx]
	mov [bp-6], ax ; y0
	add bx, 2
	mov ax, [bx]
	mov [bp-8], ax ; y1
	add bx, 2
	mov ax, [bx]
	mov [bp-10], ax ; xc
	add bx, 2
	mov ax, [bx]
	mov [bp-12], ax ; yc
	add bx, 2
	mov ax, [bx]
	mov [bp-14], ax ; c
	add bx, 2
	mov dx, [bx] ; normal
	mov ax, [bp+8] ; x
	mov bx, [bp-2] ; x0
	cmp ax, bx
	jl _wall_miss
	mov bx, [bp-4] ; x1
	cmp ax, bx
	jg _wall_miss
	mov ax, [bp+6] ; y
	mov bx, [bp-6] ; y0
	cmp ax, bx
	jl _wall_miss
	mov bx, [bp-8] ; y1
	cmp ax, bx
	jg _wall_miss


	push dx
	mov ax, [bp+8] ; x
	mov bx, [bp-10] ; xc
	mul bx
	mov cx, ax
	mov ax, [bp+6] ; y
	mov bx, [bp-12] ; yc
	mul bx
	add ax, cx
	mov bx, [bp-14] ; c
	cmp ax, bx
	pop dx
	jg _wall_miss
	jmp _wall_hit

_wall_miss:
	mov dx, 256
_wall_hit:
	pop cx
	pop bx
	pop ax
	add sp, 14
	pop bp
	ret

intersection_test: ; new point -> dx=normal? (>255 NULL)
	push bp
	mov bp, sp
	; [bp+4] new screen coord
	sub sp, 4
	; [bp-2] newx
	; [bp-4] newy
	push ax
	push bx
	push cx


	mov ax, [bp+4] ; new screen coord
	shr ax, 6
	mov cl, 5
	div cl
	mov ah, 0
	mov cx, ax ; ax = cx = newy
	mov bx, 5
	mul bx
	shl ax, 6
	mov bx, [bp+4]
	sub bx, ax ; bx = newx
	mov [bp-2], bx ; newx
	mov [bp-4], cx ; newy

	mov cx, 0
_next_wall:
	mov bx, walls
	add bx, cx

	mov ax, [bp-2] ; newx
	push ax
	mov ax, [bp-4] ; newy
	push ax
	push bx
	call intersect_wall
	add sp, 6
	cmp dx, 256
	jl _hit

	add cx, 16
	cmp cx, 16*5 ; wall count
	jne _next_wall

_no_hit:
	mov dx, 256
_hit:
	pop cx
	pop bx
	pop ax
	add sp, 4
	pop bp
	ret

draw_line:
	push bp
	mov bp, sp
	; [bp+6] theta 0-255        -> reflected theta
	; [bp+4] screen coord start -> hit point
	sub sp, 8
	; [bp-2] step
	; [bp-4] stepextra
	; [bp-6] stepdelta
	; [bp-8] distance
	push ax
	push bx
	push cx
	push es

	mov es, [back_buffer_segment]

	; init local variables
	mov ax, [bp+6] ; theta
	shl ax, 1
	mov bx, stepdelta
	add bx, ax
	mov cx, [bx]
	mov [bp-6], cx ; stepdelta

	shr ax, 6
	shl ax, 1
	mov bx, step
	add bx, ax
	mov cx, [bx]
	mov [bp-2], cx ; step
	mov bx, stepextra
	add bx, ax
	mov cx, [bx]
	mov [bp-4], cx ; stepextra


	; draw loop
	mov ax, [bp+4] ; screen coord
	mov cx, [bp-6] ; stepdelta
	shr cx, 1
	mov dx, 0
	mov [bp-8], dx
_next_pix:
	; draw this pix
	mov dl, 40 ; color
	mov bx, ax
	mov [es:bx], dl
	; increment t
	mov bx, [bp-6] ; delta
	add cx, bx
	; step logic
	cmp cx, 255
	jl _skip_stepextra
	; extrastep
	mov bx, [bp-4] ; stepextra
	add ax, bx
	sub cx, 255
_skip_stepextra:
	; step
	mov bx, [bp-2] ; step
	add ax, bx

	mov dx, [bp-8] ; distance
	inc dx
	mov [bp-8], dx ; distance
	cmp dx, 4
	jl _next_pix

	push ax
	call intersection_test ; dx = normal?
	add sp, 2
	cmp dx, 255
	jg _next_pix

	mov [bp+4], ax ; return hit point
	; dx is normal
	;mov ax, dx
	;call draw_point
	mov ax, [bp+6] ; theta
	push ax
	push dx ; normal
	call reflect_theta
	add sp, 2
	pop ax
	mov [bp+6], ax ; return reflected theta

	pop es
	pop cx
	pop bx
	pop ax
	add sp, 8
	pop bp
	ret

draw_simple_line:
	push bp
	mov bp, sp
	; [bp+4] simple line pointer
	push ax
	push bx
	push cx
	push es
	mov es, [back_buffer_segment]

	mov bx, [bp+4]
	mov ax, [bx] ; start point
	add bx, 2
	mov dx, [bx] ; step
	add bx, 2
	mov cx, [bx] ; count
	mov bx, ax ; point

	mov al, 11
	mov [es:bx], al
_simple_line_loop:
	add bx, dx
	dec cx
	mov [es:bx], al
	cmp cx, 0
	jne _simple_line_loop

	pop es
	pop cx
	pop bx
	pop ax
	pop bp
	ret

draw_point:
	push ax
	push bx
	push es

	mov es, [back_buffer_segment]
	mov bx, 0
	add bx, ax
	mov al, 7 ; color
	mov [es:bx], al

	pop es
	pop bx
	pop ax
	ret

draw_sprites:
	push bp
	mov bp, sp
	push ax
	push bx
	push cx

	mov cx, 0
_next_sls:
	mov bx, simple_line_sprites
	add bx, cx
	push bx
	call draw_simple_line
	add sp, 2
	add cx, 6
	cmp cx, 6*5 ; simple line sprites count
	jne _next_sls

	pop cx
	pop bx
	pop ax
	pop bp
	ret

blit:
	push ax
	push cx
	push es
	push ds

	mov ax, [back_buffer_segment]
	mov ds, ax
	mov ax, 0a000h
	mov es, ax
	mov si, 0
	mov di, 0
	mov cx, 320*200/2
	cld
	rep movsw

	pop ds
	pop es
	pop cx
	pop ax
	ret

kb_irqh:
	cli
	push ax
	push bx


	in al, 60h ; keyboard port

	; handle scan code
	mov bl, 10h ; 'q' make scan code
	cmp al, 10h
	je _kb_q_make
	mov bl, 4dh ; 'right' make scan code
	cmp al, bl
	je _kb_right_make
	mov bl, 0cdh ; 'right' break scan code
	cmp al, bl
	je _kb_right_break
	jmp _kb_fallthrough
_kb_q_make:
	mov bx, 0001h
	or [kb], bx
	jmp _kb_fallthrough
_kb_right_make:
	mov bx, 0002h
	or [kb], bx
	jmp _kb_fallthrough
_kb_right_break:
	mov bx, ~0002h
	and [kb], bx
_kb_fallthrough:

	; acknoledge scancode
	in al, 61h
	or al, 80h ; dissable keyboard
	out 61h, al
	and al, 7fh ; enable keyboard
	out 61h, al

	; send end of interrupt signal
	mov ax, 20h
	out 20h, ax

	pop bx
	pop ax
	sti
	iret

start:
	; enter 13h vga mode
	mov ax, 0013h
	int 10h

	; save old keyboard interrupt request handler
	push es
	mov ax, 3509h ; get kb irq
	int 21h
	mov [old_kb_irqh], es
	mov [old_kb_irqh+2], bx
	pop es
	; set kb interrupt vector
	push ds
	mov ax, 2509h ; set kb irq
	push cs
	pop ds
	mov dx, kb_irqh
	int 21h
	pop ds

	mov cx, 0
_game_loop:
	call clear
	call draw_sprites
	;call draw_point
	push cx ; theta
	push 32160 ; screen coord
	call draw_line
	call draw_line
	call draw_line
	call draw_line
	add sp, 4

	call vsync
	call blit

	inc cx
	mov ch, 0

	mov ax, [kb]
	test ax, 0001h
	jz _game_loop

	; restore keyboard interrupt vector
	push ds
	mov ax, 2509h; set kb irq
	mov dx, [old_kb_irqh+2]
	mov ds, [old_kb_irqh]
	int 21h
	pop ds

	; return to text mode
	mov ax, 0003h
	int 10h
	; exit
	mov ax, 4c00h
	int 21h

section .data
old_kb_irqh: dw 0, 0
kb: dw 0
back_buffer_segment: dw 0
step: dw 1, 320, 320, -1, -1, -320, -320, 1
stepextra: dw 320, 1, -1, 320, -320, -1, 1, -320
stepdelta: dw 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6

;tan: dw 0, 1, 3, 4, 6, 7, 9, 11, 12, 14, 16, 17, 19, 21, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 45, 47, 49, 52, 55, 58, 60, 64, 67, 70, 74, 77, 82, 86, 90, 95, 101, 106, 112, 119, 127, 135, 144, 154, 165, 178, 193, 210, 231, 255
cos: dw 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9, 9, 9, 9, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, -1, -1, -1, -1, -2, -2, -2, -2, -3, -3, -3, -3, -4, -4, -4, -4, -5, -5, -5, -5, -6, -6, -6, -6, -6, -7, -7, -7, -7, -7, -8, -8, -8, -8, -8, -8, -9, -9, -9, -9, -9, -9, -9, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -9, -9, -9, -9, -9, -9, -9, -8, -8, -8, -8, -8, -8, -7, -7, -7, -7, -7, -6, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11
sin: dw 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9, 9, 9, 9, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, -1, -1, -1, -1, -2, -2, -2, -2, -3, -3, -3, -3, -4, -4, -4, -4, -5, -5, -5, -5, -6, -6, -6, -6, -6, -7, -7, -7, -7, -7, -8, -8, -8, -8, -8, -8, -9, -9, -9, -9, -9, -9, -9, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -9, -9, -9, -9, -9, -9, -9, -8, -8, -8, -8, -8, -8, -7, -7, -7, -7, -7, -6, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, 0, 0, 0


;	x0,  x1,  y0,  y1,  xc, yc, c,   normal
walls: dw \
	0,   5,   0,   200, 1,  0,  5,    0, \
	315, 320, 0,   200, -1, 0,  -315, 128, \
	0,   320, 0,   5,   0,  1,  5,    64, \
	0,   320, 195, 200, 0,  -1, -195, 192, \
	0,   150, 0,   150, 1,  1,  150,  32
simple_line_sprites: dw \
	320*5+5, 320, 190, \
	320*5+315, 320, 190, \
	320*5+5, 1, 310, \
	320*195+5, 1, 310, \
	150, 319, 150
