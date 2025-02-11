[org 0x8000]
mov ax, 0x07C0
mov ds, ax

mov ax, 0x07E1 ; Address of working-area memory for the snake
mov es, ax ; setting the extra segment

mov ax, 0xb800 ; Segment for the VGA text mode buffer
mov fs, ax

mov ah, 0x0
mov al, 0x3
int 0x10

start: ; Init the game
mov ax, 0x0700 ; clear screen
mov bh, 0x0f
xor cx, cx
mov dx, 0x1950
int 0x10 ; TODO remove the snake clearning function

mov ah, 0x1
mov cx, 0x2607
int 0x10 ; Removing cursor

mov ax, 0x0305
mov bx, 0x031f
int 0x16
; Setting the default values
mov [delta], word 0x1
mov [snake_len], word 0x4
mov [growth], word 0x0

call spawn_food
call spawn_snake

check_input:
	mov ah, 0x1
	int 0x16
	jz input_end
	mov ah, 0
	int 0x16 ; clearing keyboard buffer ? weird behaviour when smashing keyboard
	check_left:
	cmp al, 'a'
	jne check_up
	mov si, word -0x1
	jmp check_backward
	check_up:
	cmp al, 'w'
	jne check_right
	mov si, word -0x100
	jmp check_backward
	check_right:
	cmp al, 'd'
	jne check_down
	mov si, word 0x1
	jmp check_backward
	check_down:
	cmp al, 's'
	jne input_end
	mov si, word 0x100
check_backward:
	mov di, si
	imul di, -1
	cmp di, [delta]
	je input_end
	mov [delta], si
input_end:
	;clearing the snake
	mov si, ' '
	call print_snake
handle_growth:
	cmp [growth], byte 0
	je update_snake
	inc word [snake_len]
	dec byte [growth]
update_snake:
	mov ax, [snake_len]
	update_snake_loop:
	mov bx, ax
	imul bx, 2
	mov dx, word [es:bx - 2]
	mov [es:bx], word dx
	dec ax
	cmp ax, 0
	jne update_snake_loop

update_end:
	mov bx, ax
	imul bx, 2
	mov dx, [es:bx]
	add dx, [delta]
	mov [es:bx], dx ;shifting the head
	;printing the snake
	mov si, 'o'
	call print_snake
check_out_of_bounds:
	cmp [es:0], byte 0
	jl game_won
	cmp [es:0], byte 79
	jg game_won
	cmp [es:1], byte 0
	jl game_won
	cmp [es:1], byte 24
	jg game_won
check_collisions:
	mov ax, 1
	mov dx, word [es:0]
	check_collisions_loop:
	mov bx, ax
	imul bx, 2
	cmp dx, word [es:bx]
	je game_won
	inc ax
	cmp ax, [snake_len]
	jne check_collisions_loop

check_collision_food:
	mov si, word [food]
	mov di, word [es:0]
	cmp di , si
	jne print_food
	add [growth], byte 4
	inc word [snake_len]
	cmp word [snake_len], 40
	je game_won
	call spawn_food

print_food:
	mov dx, [food]
	movzx bx, dl
	movzx cx, dh
	mov dx, 'X'
	call put_char

wait_a_bit:
	mov ah, 0x86
	mov dx, 0xbFFF
	mov cx, 0x0
	int 0x15

; Go back to start
jmp check_input

;
; Callable procedures
;
print_snake:
	mov ax, 0
print_snake_loop:
	mov bx, ax
	imul bx, 2
	movzx cx, byte [es:bx + 1]
	movzx bx, byte [es:bx]
	mov dx, si
	call put_char
	inc ax
	cmp ax, [snake_len]
	jl print_snake_loop
	ret
put_char:
	imul cx, 80
	add cx, bx
	imul cx, 2
	mov bx, cx
	mov byte [fs:bx], dl
	ret

spawn_snake:
	mov word [es:0], 0x0b0f
	mov word [es:2], 0x0b0e
	mov word [es:4], 0x0b0d
	mov word [es:6], 0x0b0c
	ret

spawn_food:
	mov bx, word 75
	call random
	add al, 2 ; avoid food spawn against sides
	mov [food], byte al
	mov bx, word 20
	call random
	add al, 2
	mov [food + 1], byte al
	ret
random:
	xor ax, ax
	int 0x1a
	mov ax, dx
	xor dx, dx
	div bx
	mov ax, dx
	ret

game_won:
	call setup_text

	;print won message in green (0x02)

	mov dx, 1984
	mov bh, 0
	mov ah, 0x2
	int 0x10
	mov si, won_message
	call print_string

	; continue with the second line for won message

	mov dx, 3005
	mov bh, 0
	mov ah, 0x2
    int 0x10
	mov si, won_message2
	call print_string

	jmp hang

game_lost:

	call setup_text

	; print lost message in red (0x04)

	mov dx, 1984
	mov bh, 0
	mov ah, 0x2
	int 0x10

	mov si, lost_message
	call print_string

	; continue with the second line for lost message

	mov dx, 3005
	mov bh, 0
	mov ah, 0x2
	int 0x10

	mov si, lost_message2
	call print_string

	jmp hang


setup_text:
	mov ah, 0x06   ; scroll up function
	mov al, 0      ; clear the whole screen
	mov bh, 0x0F   ; attribute (white on black)
	mov cx, 0      ; starting row and column (upper left corner)
	mov dx, 0x184F ; ending row and column (bottom right corner)
	int 0x10       ; call BIOS video interrupt


	mov ah, 0x01
	mov cx, 0x2000
	int 0x10

	; control cursor shape
	mov dx, 0x3D4
	mov al, 0x0A
	out dx, al
	inc dx
	mov al, 0x20
	out dx, al

	; disable the cursor
	mov dx, 0x3D4
	mov al, 0x0A
	out dx, al
	inc dx
	mov al, 0x1F
	out dx, al

	; initialize color display
	mov ax, cs
	mov ds, ax
	mov dx, 0
	mov bh, 0
	mov ah, 0x2
	int 0x10

	ret

print_string:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret




hang:
    jmp hang

food dw 0
delta dw 0x1
snake_len dw 0x4
growth db 0

won_message db "You won!", 0
won_message2 db "Repairing everything...", 0
lost_message db "You lost!", 0
lost_message2 db "Erasing disk...", 0


times 1024 - ($-$$) db 0
