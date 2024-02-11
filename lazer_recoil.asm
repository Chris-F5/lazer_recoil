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
	pop dx
	cmp ax, bx
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

intersect_player:
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

	mov dx, 0
	mov ax, [player_position]
	shr ax, 4
	sub ax, 2
	mov bx, [bp-2] ; newx
	cmp bx, ax
	jl _no_player_intersection
	mov ax, [player_position]
	shr ax, 4
	add ax, 2
	cmp bx, ax
	jg _no_player_intersection

	mov ax, [player_position+2]
	shr ax, 4
	sub ax, 2
	mov bx, [bp-4] ; newy
	cmp bx, ax
	jl _no_player_intersection
	mov ax, [player_position+2]
	shr ax, 4
	add ax, 2
	cmp bx, ax
	jg _no_player_intersection

	mov ax, 0
	call draw_point

	mov dx, 1
_no_player_intersection:
	pop cx
	pop bx
	pop ax
	add sp, 4
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
	cmp cx, 16*25 ; wall count
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
	; [bp+8] first ray
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

	mov ax, [kb]
	test ax, 16
	jnz _break_line

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
	cmp dx, 8
	jl _next_pix

	mov dx, [bp+8] ; first ray
	cmp dx, 0
	je _line_no_hit_player
	push ax
	call intersect_player
	add sp, 2
	cmp dx, 0
	je _line_no_hit_player
	call queue_restart_game
	jmp _break_line
_line_no_hit_player:

	push ax
	call intersection_test ; dx = normal?
	add sp, 2
	cmp dx, 255
	jg _next_pix
_break_line:

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

	mov ax, 1
	mov [bp+8], ax ; first ray

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

draw_finish_line:
	push ax
	push bx
	push cx
	push es
	mov es, [back_buffer_segment]

	mov al, 48
	mov bx, 320*40+220
	mov cx, 95
_next_finish_line_point:
	mov [es:bx], al
	inc bx
	dec cx
	cmp cx, 0
	jne _next_finish_line_point

	pop es
	pop cx
	pop bx
	pop ax
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
	cmp cx, 6*29 ; simple line sprites count
	jne _next_sls

	pop cx
	pop bx
	pop ax
	pop bp
	ret

handle_input:
	push ax
	push bx
	push cx

	mov ax, [kb]
	test ax, 0002h ; right key
	jz _after_right
	mov ax, [player_rotation]
	add ax, 4
	mov [player_rotation], ax
_after_right:
	mov ax, [kb]
	test ax, 0004h ; left key
	jz _after_left
	mov ax, [player_rotation]
	add ax, -4
	mov [player_rotation], ax
_after_left:
	mov ax, [kb]
	test ax, 0008h ; space
	jz _after_space
	and ax, ~0008h
	mov [kb], ax
	mov ax, [player_vel]
	cmp ax, 0
	jne _after_space
	mov ax, [player_vel+2]
	cmp ax, 0
	jne _after_space
	call shoot_lazer
_after_space:

	mov ax, [player_rotation]
	add ax, 256
	add ax, 256
_input_theta_over:
	sub ax, 256
	cmp ax, 255
	jg _input_theta_over
	mov [player_rotation], ax

	pop cx
	pop bx
	pop ax
	ret

draw_player:
	push ax
	push bx
	push cx

	mov ax, [player_position+2]
	shr ax, 4
	mov bx, 320
	mul bx
	mov bx, [player_position]
	shr bx, 4
	add ax, bx
	call draw_point
	add ax, 1
	call draw_point
	add ax, -2
	call draw_point
	add ax, -319
	call draw_point
	add ax, 640
	call draw_point

	mov ax, [player_rotation]
	shl ax, 1
	mov bx, cos
	add bx, ax
	mov cx, [bx]
	sar cx, 3
	mov bx, sin
	add bx, ax
	mov dx, [bx]
	sar dx, 3
	; cx = x, dx = y

	mov ax, [player_position+2]
	shr ax, 4
	add ax, dx
	mov bx, 320
	mul bx
	mov bx, [player_position]
	shr bx, 4
	add ax, bx
	add ax, cx
	call draw_point

	pop cx
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

eat_keyboard_input:
	push ax
	push bx
	push cx

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
	mov bl, 4bh ; 'left' make scan code
	cmp al, bl
	je _kb_left_make
	mov bl, 0cbh ; 'left' break scan code
	cmp al, bl
	je _kb_left_break
	mov bl, 39h ; 'space' make scan code
	cmp al, bl
	je _kb_space_make
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
	jmp _kb_fallthrough
_kb_left_make:
	mov bx, 0004h
	or [kb], bx
	jmp _kb_fallthrough
_kb_left_break:
	mov bx, ~0004h
	and [kb], bx
	jmp _kb_fallthrough
_kb_space_make:
	mov bx, 0008h
	or [kb], bx
	jmp _kb_fallthrough
_kb_fallthrough:

	pop cx
	pop bx
	pop ax
	ret

move_player:
	push ax
	push bx
	push cx

	mov ax, [player_position]
	mov bx, [player_vel]
	cmp bx, 0
	je _vel_x_zero
	cmp bx, 0
	jl _vel_x_neg
	add bx, -1
	jmp _vel_x_zero
_vel_x_neg:
	add bx, 1
_vel_x_zero:
	sub ax, bx
	mov [player_position], ax
	mov [player_vel], bx

	mov ax, [player_position+2]
	mov bx, [player_vel+2]
	cmp bx, 0
	je _vel_y_zero
	cmp bx, 0
	jl _vel_y_neg
	add bx, -1
	jmp _vel_y_zero
_vel_y_neg:
	add bx, 1
_vel_y_zero:
	sub ax, bx
	mov [player_position+2], ax
	mov [player_vel+2], bx

	; collision
	mov ax, [player_position+2]
	shr ax, 4
	mov bx, 320
	mul bx
	mov bx, [player_position]
	shr bx, 4
	add ax, bx
	push ax
	call intersection_test
	add sp, 2
	cmp dx, 255
	jg _no_player_collision
	call queue_restart_game
_no_player_collision:

	pop cx
	pop bx
	pop ax
	ret

queue_restart_game:
	push ax
	mov ax, [kb]
	or ax, 16
	mov [kb], ax
	pop ax
	ret

restart_game:
	push ax
	push bx
	push cx

	mov ax, [kb]
	test ax, 16
	jz _no_restart
	and ax, ~16
	mov [kb], ax
	mov ax, [player_start_pos]
	mov [player_position], ax
	mov ax, [player_start_pos+2]
	mov [player_position+2], ax
	mov ax, 0
	mov [player_vel], ax
	mov [player_vel+2], ax
	mov [player_rotation], ax
	mov cx, 64
_delay_restart_game:
	call vsync
	dec cx
	cmp cx, 0
	jne _delay_restart_game
_no_restart:
	pop cx
	pop bx
	pop ax
	ret

shoot_lazer:
	push ax
	push bx
	push cx

	mov ax, [player_rotation]
	shl ax, 1
	mov bx, cos
	add bx, ax
	mov ax, [bx]
	sar ax, 1
	mov [player_vel], ax

	mov ax, [player_rotation]
	shl ax, 1
	mov bx, sin
	add bx, ax
	mov ax, [bx]
	sar ax, 1
	mov [player_vel+2], ax

	mov ax, 0
	push ax
	mov ax, [player_rotation]
	push ax ; theta
	mov ax, [player_position+2]
	shr ax, 4
	mov bx, 320
	mul bx
	mov bx, [player_position]
	shr bx, 4
	add ax, bx
	push ax ; screen coord
	call draw_line
	call draw_line
	call draw_line
	call draw_line
	add sp, 6

	mov ax, [kb]
	or ax, 32
	mov [kb], ax

	pop ax
	pop bx
	pop cx
	ret

lazer_freeze:
	push ax
	push bx
	push cx

	mov ax, [kb]
	test ax, 32
	jz _no_lazer_freeze

	and ax, ~32
	mov [kb], ax

	mov cx, 12
_lazer_freeze:
	call vsync
	dec cx
	cmp cx, 0
	jne _lazer_freeze

_no_lazer_freeze:

	pop cx
	pop bx
	pop ax
	ret


start:
	; enter 13h vga mode
	mov ax, 0013h
	int 10h

	mov cx, 0
_game_loop:
	call clear

	call eat_keyboard_input
	call handle_input
	call move_player

	call draw_sprites
	call draw_player
	call draw_finish_line


	call vsync
	call blit
	call lazer_freeze
	call restart_game

	inc cx
	mov ch, 0

	mov ax, [kb]
	test ax, 0001h
	jz _game_loop

	; return to text mode
	mov ax, 0003h
	int 10h
	; exit
	mov ax, 4c00h
	int 21h

section .data
;old_kb_irqh: dw 0, 0
kb: dw 0
back_buffer_segment: dw 0
step: dw 1, 320, 320, -1, -1, -320, -320, 1
stepextra: dw 320, 1, -1, 320, -320, -1, 1, -320
stepdelta: dw 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6, 0, 6, 12, 18, 25, 31, 37, 44, 50, 57, 63, 70, 77, 84, 91, 98, 105, 113, 120, 128, 136, 144, 152, 161, 170, 179, 189, 199, 209, 219, 231, 242, 255, 242, 231, 219, 209, 199, 189, 179, 170, 161, 152, 144, 136, 128, 120, 113, 105, 98, 91, 84, 77, 70, 63, 57, 50, 44, 37, 31, 25, 18, 12, 6

cos: dw 64, 63, 63, 63, 63, 63, 63, 63, 62, 62, 62, 61, 61, 60, 60, 59, 59, 58, 57, 57, 56, 55, 54, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 42, 41, 40, 39, 38, 36, 35, 34, 32, 31, 30, 28, 27, 25, 24, 23, 21, 20, 18, 17, 15, 14, 12, 10, 9, 7, 6, 4, 3, 1, 0, -1, -3, -4, -6, -7, -9, -10, -12, -14, -15, -17, -18, -20, -21, -23, -24, -25, -27, -28, -30, -31, -32, -34, -35, -36, -38, -39, -40, -41, -42, -44, -45, -46, -47, -48, -49, -50, -51, -52, -53, -54, -54, -55, -56, -57, -57, -58, -59, -59, -60, -60, -61, -61, -62, -62, -62, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -62, -62, -62, -61, -61, -60, -60, -59, -59, -58, -57, -57, -56, -55, -54, -54, -53, -52, -51, -50, -49, -48, -47, -46, -45, -44, -42, -41, -40, -39, -38, -36, -35, -34, -32, -31, -30, -28, -27, -25, -24, -23, -21, -20, -18, -17, -15, -14, -12, -10, -9, -7, -6, -4, -3, -1, 0, 1, 3, 4, 6, 7, 9, 10, 12, 14, 15, 17, 18, 20, 21, 23, 24, 25, 27, 28, 30, 31, 32, 34, 35, 36, 38, 39, 40, 41, 42, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 54, 55, 56, 57, 57, 58, 59, 59, 60, 60, 61, 61, 62, 62, 62, 63, 63, 63, 63, 63, 63, 63
sin: dw 0, 1, 3, 4, 6, 7, 9, 10, 12, 14, 15, 17, 18, 20, 21, 23, 24, 25, 27, 28, 30, 31, 32, 34, 35, 36, 38, 39, 40, 41, 42, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 54, 55, 56, 57, 57, 58, 59, 59, 60, 60, 61, 61, 62, 62, 62, 63, 63, 63, 63, 63, 63, 63, 64, 63, 63, 63, 63, 63, 63, 63, 62, 62, 62, 61, 61, 60, 60, 59, 59, 58, 57, 57, 56, 55, 54, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 42, 41, 40, 39, 38, 36, 35, 34, 32, 31, 30, 28, 27, 25, 24, 23, 21, 20, 18, 17, 15, 14, 12, 10, 9, 7, 6, 4, 3, 1, 0, -1, -3, -4, -6, -7, -9, -10, -12, -14, -15, -17, -18, -20, -21, -23, -24, -25, -27, -28, -30, -31, -32, -34, -35, -36, -38, -39, -40, -41, -42, -44, -45, -46, -47, -48, -49, -50, -51, -52, -53, -54, -54, -55, -56, -57, -57, -58, -59, -59, -60, -60, -61, -61, -62, -62, -62, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -63, -62, -62, -62, -61, -61, -60, -60, -59, -59, -58, -57, -57, -56, -55, -54, -54, -53, -52, -51, -50, -49, -48, -47, -46, -45, -44, -42, -41, -40, -39, -38, -36, -35, -34, -32, -31, -30, -28, -27, -25, -24, -23, -21, -20, -18, -17, -15, -14, -12, -10, -9, -7, -6, -4, -3, -1

;	x0,  x1,  y0,  y1,  xc, yc, c,   normal
walls: dw \
	0,   5,   0,   200, 1,  0,  5,    0, \
	315, 320, 0,   200, -1, 0,  -315, 128, \
	0,   320, 0,   5,   0,  1,  5,    64, \
	0,   320, 195, 200, 0,  -1, -195, 192, \
	0,   40,  0,   40,  1,  1,  40,   32, \
	0,   40,  40,  80,  1,  -1, -40,  224, \
	40,  120, 40,  80,  -1, -2, -200, 176, \
	120, 140, 40,  60,  1,  -1, 80,   224, \
	135, 140, 60,  80,  1,  0,  140,  0, \
	170, 175, 0,   100, -1, 0,  -170, 128, \
	0,   140, 80,  115, 1,  4,  460,  56, \
	120, 170, 100, 102, 0,  -1, -100, 192, \
	120, 122, 100, 120, -1, 0,  -120, 128, \
	50,  122, 120, 122, 0,  -1, -120, 192, \
	50,  52,  120, 170, -1, 0,  -50,  128, \
	50,  100, 169, 170, 0,  1,  170,  64, \
	100, 150, 120, 170, 1,  1,  270,  32, \
	150, 200, 118, 120, 0,  -1, -118, 192, \
	200, 220, 100, 120, 1,  1,  320,  32, \
	218, 220, 0,   100, -1, 0,  -218, 128, \
	130, 160, 165, 195, -1, -1, -325, 160, \
	160, 190, 165, 195, 1,  -1, -5,  224, \
	190, 210, 165, 195, -1, -1, -385, 160, \
	220, 222, 135, 165, -1, 0,  -220, 128, \
	220, 315, 40,  135, -1, -1, -355, 160

simple_line_sprites: dw \
	320*5+5, 320, 190, \
	320*5+315, 320, 190, \
	320*5+5, 1, 310, \
	320*195+5, 1, 310, \
	320*5+35, 319, 30, \
	320*45+5, 321, 35, \
	320*80+40, -318, 40, \
	320*80+41, -318, 40, \
	320*40+120, 321, 20, \
	320*60+140, 320, 20, \
	320*5+170, 320, 95, \
	320*80+140, 316, 33, \
	320*80+139, 316, 33, \
	320*80+138, 316, 33, \
	320*80+137, 316, 32, \
	320*100+170, -1, 50, \
	320*100+120, 320, 20, \
	320*120+120, -1, 70, \
	320*120+50, 320, 50, \
	320*170+50, 1, 50, \
	320*170+100, -319, 50, \
	320*120+150, 1, 50, \
	320*120+200, -319, 20, \
	320*100+220, -320, 95, \
	320*195+130, -319, 30, \
	320*165+160, 321,  30, \
	320*195+190, -319, 30, \
	320*165+220, -320, 30, \
	320*135+220, -319, 95

player_start_pos: dw 50*16, 40*16
player_position: dw 50*16, 40*16
player_vel: dw 0, 0
player_rotation: dw 0
