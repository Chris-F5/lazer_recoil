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
	mov bx, 2
	mul bx ; ax = theta * 2
	mov bx, step
	add bx, ax
	mov cx, [bx]
	mov [bp-2], cx ; step
	mov bx, stepextra
	add bx, ax
	mov cx, [bx]
	mov [bp-4], cx ; stepextra
	mov bx, stepdelta
	add bx, ax
	mov cx, [bx]
	mov [bp-6], cx ; stepdelta
	mov bx, stepdistance
	add bx, ax
	mov cx, [bx]
	mov [bp-8], cx ; stepdistance

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
	push ax
	push bx
	push es

	mov es, [back_buffer_segment]
	mov ax, 10 ; y
	mov bx, 320
	mul bx
	add ax, 50 ; x
	;mov ax, [stepdelta]
	mov bx, 0
	add bx, ax
	mov al, 7 ; color
	mov [es:bx], al

	pop es
	pop bx
	pop ax
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
	;call draw_point
	push 6200 ; distance
	push cx ; theta
	push 32160 ; screen coord
	call draw_line
	add sp, 6
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
step: dw 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
stepextra: dw 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320, -320
stepdelta: dw 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6
stepdistance: dw 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 65, 66, 66, 67, 67, 68, 69, 70, 70, 71, 72, 73, 74, 75, 76, 78, 79, 81, 82, 84, 86, 88, 90, 88, 86, 84, 82, 81, 79, 78, 76, 75, 74, 73, 72, 71, 70, 70, 69, 68, 67, 67, 66, 66, 65, 65, 65, 64, 64, 64, 64, 64, 64, 64
;back_buffer: times 320*200 db 0
