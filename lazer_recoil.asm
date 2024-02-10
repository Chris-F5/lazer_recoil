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

draw_line:
	push bp
	mov bp, sp
	; [bp+8] distance 64=1px
	; [bp+6] theta 0-255
	; [bp+4] screen coord start
	sub sp, 8
	; [bp-2] step
	; [bp-4] stepextra
	; [bp-6] stepdelta
	; [bp-8] stepdistance
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
	mov bx, stepdistance
	add bx, ax
	mov cx, [bx]
	mov [bp-8], cx ; stepdistance

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
_next_pix:
	; draw this pix
	mov dl, 7 ; color
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
	; subtract distance
	mov bx, [bp+8] ; distance
	mov dx, [bp-8] ; stepdistance
	sub bx, dx
	;sub bx, 1
	mov [bp+8], bx ; distance
	cmp bx, 0
	jg _next_pix

	pop es
	pop cx
	pop bx
	pop ax
	add sp, 8
	pop bp
	ret

draw_point:
	push bx
	push es

	mov es, [back_buffer_segment]
	;mov ax, 10 ; y
	;mov bx, 320
	;mul bx
	;add ax, 50 ; x
	;mov ax, [stepdelta]
	mov bx, 0
	add bx, ax
	mov al, 7 ; color
	mov [es:bx], al

	pop es
	pop bx
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

;distance_to_line:
;	push bp
;	mov bp, sp
;	; [bp+14] x
;	; [bp+12] y
;	; [bp+10] x0
;	; [bp+8]  y0
;	; [bp+6]  nx
;	; [bp+4]  ny
;	push bx
;	push cx
;
;	mov ax, [bp+10] ; x0
;	mov bx, [bp+14] ; x
;	sub ax, bx ; ax = x0 - x
;	;mov bx, ax
;	;sar bx, 15
;	;xor ax, bx
;	;sub ax, bx ; ax = (ax ^ (ax >> 15)) - (ax >> 15)
;	mov [bp+10], ax ; x0 = x0 - x
;	mov ax, [bp+8] ; y0
;	mov bx, [bp+12] ; y
;	sub ax, bx
;	;mov bx, ax
;	;sar bx, 15
;	;xor ax, bx
;	;sub ax, bx ; ax = (ax ^ (ax >> 15)) - (ax >> 15)
;	mov [bp+8], ax ; y0 = y0 - y
;
;	mov ax, [bp+6] ; nx
;	mov bx, [bp+10] ; x0
;	mul bx
;	mov cx, ax ; cx = nx * x0
;	mov ax, [bp+4] ; ny
;	mov bx, [bp+8] ; y0
;	mul bx
;	add ax, cx ; ax = nx*x0 + ny*y0
;
;	pop cx
;	pop bx
;	pop bp
;	ret
;
;ray_intersect:
;	push bp
;	mov bp, sp
;	; [bp+8] x
;	; [bp+6] y
;	; [bp+4] theta
;	sub sp, 4
;	; [bp-2] perpendicular to line
;	; [bp-4] parallel to line
;	push ax
;	push bx
;	push cx
;
;	mov ax, [bp+8] ; x
;	push ax
;	mov ax, [bp+6] ; y
;	push ax
;	mov ax, [walls] ; x0
;	push ax
;	mov ax, [walls+2] ; y0
;	push ax
;	mov ax, [walls+4] ; nx
;	push ax
;	mov ax, [walls+6] ; ny
;	push ax
;	call distance_to_line
;	;mov bx, ax
;	;sar bx, 15
;	;xor ax, bx
;	;sub ax, bx ; ax = (ax ^ (ax >> 15)) - (ax >> 15)
;	mov [bp-2], ax ; perpendicular to line
;	add sp, 12
;	call draw_point
;
;	mov ax, [bp+8] ; x
;	push ax
;	mov ax, [bp+6] ; y
;	push ax
;	mov ax, [walls] ; x0
;	push ax
;	mov ax, [walls+2] ; y0
;	push ax
;	mov ax, [walls+8] ; px
;	push ax
;	mov ax, [walls+10] ; py
;	push ax
;	call distance_to_line
;	mov [bp-4], ax ; parallel to line
;	add sp, 12
;	call draw_point
;
;	mov ax, [walls+12] ; line theta
;	mov bx, [bp+4] ; theta
;	sub ax, bx ; al = line_theta - theta
;;	mov bl, al
;;	sar bl, 7
;;	xor al, bl
;;	sub al, bl ; al = |al|
;;	mov ah, 0
;;	mov dl, bl ; dl is now the theta sign bit
;;
;;	cmp ax, 55
;;	jl _in_direction
;;	mov ax, 0
;;	jmp _intersect_no_hit
;;_in_direction:
;;	; ax is now the theta delta
;;	jmp _intersect_no_hit ; TMP
;;
;;	mov bx, tan
;;	add bx, ax
;;	mov ax, [bx] ; ax = tan(theta delta)
;;	mov bx, [bp-2] ; perpendicular to line
;;	shl bx, 5
;;	mul bx
;;	shl ax, 1 ; ax = perpendicular*tan(theta delta)
;;
;;
;;	mov bx, [bp-4] ; parallel to line
;;
;;	mov bx, [bp-4] ; paralell to line
;;	cmp dl, 0
;;	je _pos_theta_delta
;;	sub bx, ax
;;	jmp _end_theta_delta
;;_pos_theta_delta:
;;	add bx, ax
;;_end_theta_delta:
;;	; bx is now paralell distance from x0,y0
;;	mov ax, bx
;;	sar bx, 15
;;	xor ax, bx
;;	sub ax, bx ; bx = abs(bx)
;;
;;	;mov ax, 0
;;	;cmp bx, 1280
;;	;jl _intersect_no_hit
;;	;mov ax, 1
;_intersect_no_hit:
;	pop cx
;	pop bx
;	pop ax
;	add sp, 4
;	pop bp
;	ret

ray_intersect:
	push bp
	mov bp, sp
	; [bp+14] sx ; ray
	; [bp+12] sy
	; [bp+10] rtheta
	; [bp+ 8] ax ; line
	; [bp+ 6] ay
	; [bp+ 4] dtheta
	sub sp, 8
	; [bp-2] rx
	; [bp-4] ry
	; [bp-6] dx
	; [bp-8] dy
	push ax
	push bx
	push cx

	; set rx, ry, dx, dy
	mov ax, [bp+10] ; rtheta
	shl ax, 1
	mov bx, cos
	add bx, ax
	mov cx, [bx]
	mov [bp-2], cx ; rx
	mov bx, sin
	add bx, ax
	mov cx, [bx]
	mov [bp-4], cx ; ry
	mov ax, [bp+4] ; dtheta
	shl ax, 1
	mov bx, cos
	add bx, ax
	mov cx, [bx]
	mov [bp-6], cx ; dx
	mov bx, sin
	add bx, ax
	mov cx, [bx]
	mov [bp-8], cx ; dy

	; set ux, uy
	mov ax, [bp+8] ; ax
	mov bx, [bp+14] ; sx
	sub ax, bx
	mov [bp+8], ax ; ax = ux
	mov ax, [bp+6] ; ay
	mov bx, [bp+12] ; sy
	sub ax, bx
	mov [bp+6], ax ; ay = uy

	; denominator
	mov ax, [bp-6] ; dx
	mov bx, [bp-4] ; ry
	mul bx
	mov cx, ax
	mov ax, [bp-8] ; dy
	mov bx, [bp-2] ; rx
	mul bx
	add cx, ax ; cx = denominator (<256)

	; lambda numerator
	mov ax, [bp-2] ; rx
	mov bx, [bp+6] ; uy
	mul bx
	mov dx, ax
	mov ax, [bp-4] ; ry
	mov bx, [bp+8] ; ux
	mul bx
	mov bx, -1
	mul bx
	add dx, ax ; dx = lambda numerator

	cmp cl, 0
	je _no_intersect

	div cl ; ax = lambda
	jmp _intersect ; tmp
	cmp ax, 0
	jl _no_intersect
	cmp ax, 128
	jg _no_intersect

	; t numerator
	mov ax, [bp-6] ; dx
	mov bx, [bp+6] ; uy
	mul bx
	mov dx, ax
	mov ax, [bp-8] ; dy
	mov bx, [bp+8] ; ux
	mul bx
	mov bx, -1
	mul bx
	add dx, ax ; dx = t numerator

	div cl ; ax = t
	shr ax, 2
	jmp _intersect
_no_intersect:
	mov ax, 0
_intersect:
	call draw_point
	pop cx
	pop bx
	pop ax
	add sp, 8
	pop bp
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
	;call draw_point
	push 6200 ; distance
	push cx ; theta
	push 32160 ; screen coord
	call draw_line
	add sp, 6

	push 160 ; sx ; ray
	push 100 ; sy
	push cx  ; rtheta
	push 0  ; ax ; line
	push 0  ; ay
	push 0  ; dtheta
	call ray_intersect
	sub sp, 12

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
stepdistance: dw 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64

;tan: dw 0, 1, 3, 4, 6, 7, 9, 11, 12, 14, 16, 17, 19, 21, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 45, 47, 49, 52, 55, 58, 60, 64, 67, 70, 74, 77, 82, 86, 90, 95, 101, 106, 112, 119, 127, 135, 144, 154, 165, 178, 193, 210, 231, 255
cos: dw 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9, 9, 9, 9, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, -1, -1, -1, -1, -2, -2, -2, -2, -3, -3, -3, -3, -4, -4, -4, -4, -5, -5, -5, -5, -6, -6, -6, -6, -6, -7, -7, -7, -7, -7, -8, -8, -8, -8, -8, -8, -9, -9, -9, -9, -9, -9, -9, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -9, -9, -9, -9, -9, -9, -9, -8, -8, -8, -8, -8, -8, -7, -7, -7, -7, -7, -6, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11
sin: dw 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9, 9, 9, 9, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, -1, -1, -1, -1, -2, -2, -2, -2, -3, -3, -3, -3, -4, -4, -4, -4, -5, -5, -5, -5, -6, -6, -6, -6, -6, -7, -7, -7, -7, -7, -8, -8, -8, -8, -8, -8, -9, -9, -9, -9, -9, -9, -9, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -10, -9, -9, -9, -9, -9, -9, -9, -8, -8, -8, -8, -8, -8, -7, -7, -7, -7, -7, -6, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, 0, 0, 0


; x0, y0, nx, ny, px, py, normal
walls: dw 100, 50, -15, 62, 62, 15, 74
