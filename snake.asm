; Example to print hello world to the screen from the BIOS
;
; Can be used with:
;   nasm -f bin snake.asm -o snake.img
;   qemu-system-x86_64 -hda snake.img
;

; if you want to assemble this into anything other than a raw binary, comment this out
%define bios_file

%ifdef bios_file
org 0x7c00
%endif

BITS 16
CPU 8086                    ; only 8086 instructions are supported in BIOS

blockWidth: equ 10
screenWidth: equ 320
screenHeight: equ 200
up: equ 0x77                ; w
down: equ 0x73              ; s
left: equ 0x61              ; a
right: equ 0x64             ; d

foodColour: equ 12          ; red
tailColour: equ 5           ; magenta
upBodyColour: equ 31        ; white
downBodyColour: equ 30      ; slightly less white
leftBodyColour: equ 29      ; slightly more less white
rightBodyColour: equ 28     ; even more less white
initialLength: equ 10
; within data segment 0xa0000 - 0xaffff:
;
;   0x0000 - 0xf9ff is the visible screen graphics (320x200 = 0xfa00 = 64000 bytes)
;   0xfa00 - fxffff is free real estate (1535 bytes)

headX: equ 0xfa00
headY: equ 0xfa02
oldTime: equ 0xfa04
currentColour: equ 0xfa06
currentDirection: equ 0xfa08
tailX: equ 0xfa0a
tailY: equ 0xfa0c
length: equ 0xfa0e
lastDirection: equ 0xfa10
score: equ 0xfa12


start:
    mov ax, 0x0013              ; 00 = set video mode, 13 = 320x200 8-bit colour
    int 0x10                    ; call bios video services

    mov ax, 0xa000
    mov ds, ax                  ; goes to data segment 0xa0000
    mov es, ax                  ; goes to 0xfa00 within 0xa0000

    mov al, 100                  ; start x
    mov [tailX], al             ; store tail x
    mov [headX], al             ; store start x

    inc word [tailY]            ; increment tail to make initSnake loop simpler

    mov al, down                ; start going down
    mov [currentDirection], al  ; store current direction
    mov al, downBodyColour      ; start going down
    mov [currentColour], al     ; store current colour
    mov cx, initialLength - 1   ; cx is the loop counter
initSnake:
    call moveHead
    call printSnakeToScreen     ; draw some initial chunks of the snake
    loop initSnake              ; cx is the loop counter
    



delayUntilTick:
    xor ax, ax                  ; 0x00 = reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    cmp dx, [oldTime]           ; wait for change
    je delayUntilTick           ; jump back up if the time is still the same
    mov [oldTime], dx           ; Save new current time

    mov ah, 0x01                ; 0x01 = check for keypress
    int 0x16                    ; calls bios keyboard services
    jnz setDirection            ; jump if there is a key waiting
returnSetDirection:

    call moveHead
    mov [currentColour], al     ; store current colour
    mov [di], al                ; draw over the old block with the new colour
    call setDiToHead
    call eraseSnakeTail
    call printSnakeToScreen
    call writeScore


    mov ah, 0x00                ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    and dl, 0b0011_1111         ; draw food ever 64 ticks
    jnz delayUntilTick
    call drawFood
    jmp delayUntilTick          ; loop forever




setDirection:
    mov ah, 0x00                ; fetches the keystroke from the keyboard buffer
    int 0x16                    ; call bios keyboard services

; we can stop the snake from going back into itself by doing this check
;
; up:    0111 0111  (w)
; down:  0111 0011  (s)
; left:  0110 0001  (a)
; right: 0110 0100  (d)
;   if (al AND 0001 0000) XOR (currentDirection AND 0001 0000) is zero, ignore the key

    mov bl, al                  ; AL contains the key that was pressed
    mov ah, [currentDirection]
    and ah, 0b0001_0000
    and bl, 0b0001_0000
    xor ah, bl
    jz returnSetDirection       ; ignore the key

    mov [currentDirection], al  ; store the new direction
    jmp returnSetDirection



printSnakeToScreen:
    call setDiToHead
    xor ax, ax
    mov al, [di]
    sub al, rightBodyColour     ; rightBodyColour is the lowest number
    jz gameOverManGameOver
    dec ax
    jz gameOverManGameOver
    dec ax
    jz gameOverManGameOver
    dec ax
    jz gameOverManGameOver
    mov al, [currentColour]
    mov [di], al                ; write to screen
    ret


gameOverManGameOver:
    mov al, 12                  ; red
    mov [di], al                ; Write to screen
    jmp $                       ; loop here forever


drawFood:
    mov ax, dx
retryDrawFood:
    mov bx, 63999               ; dividing here to make sure we're actually on the screen
    div bx                      ; divides AX by BX, puts remainder in DX

    mov di, dx                  ; take the remainder of our division and put it in DI
    cmp byte [di], 0            ; check if that pixel has already been drawn to
    jne retryDrawFood           ; try scramble the numbers again

    mov cl, foodColour
    mov [di], cl                ; draw to the screen
    call setDiToHead            ; set DI back to where it should be
    ret 
    


writeScore:
    mov bx, [score]             ; set BX to score
    mov dx, 5                   ; number of characters to print

writeScoreLoop:
    dec dx                      ; because position is zero indexed
    mov ah, 0x02                ; set cursor position to row DH, column DL
    int 0x10                    ; call bios video services

    xor dx, dx                  ; zero out DX, it is used as the high word in the division
    mov ax, bx                  ; copy score into AX
    mov cx, 10                  ; set divisor
    div cx                      ; quotient in AX, remainder in DX
    mov bx, ax                  ; copy score / 10 into BX
    mov al, dl                  ; get the remainder (this is the number we want to print)

    mov cl, bl                  ; backup BL to CL
    mov bl, 7                   ; colour attribute: light grey
    add al, 0x30                ; 0x30 = "0" to get the ASCII character
    mov ah, 0x0e                ; TTY mode, write ASCII character in AL
    int 0x10                    ; call bios video services
    mov bl, cl                  ; restore BL

    mov ah, 0x03                ; get cursor position, to row DH, column DL
    int 0x10                    ; call bios video services
    dec dx                      ; subtract because we auto-advanced on the TTY print
    jnz writeScoreLoop
    ret



ateFood:
    inc word [score]
    ret

eraseSnakeTail:
    cmp byte [di], foodColour   ; is the head on a piece of food?
    je ateFood                  ; if we're about to eat food, don't erase the tail

    mov ax, [tailY]
    mov bx, [tailX]
    mov cx, screenWidth         ; equal to the number of pixels per row
    mul cx                      ; multiplies AX and DX to get to tailY in screen memory
    add ax, bx                  ; moves along the row to get to tailX in screen memory
    mov si, ax                  ; sets SI to point to the current pixel

    mov dl, [tailY]             ; load the tail Y in dl (only needs 8 bits)

    xor ax, ax
    mov al, [si]
    sub al, rightBodyColour     ; rightBodyColour is the lowest number
    jz moveTailRight
    dec ax
    jz moveTailLeft
    dec ax
    jz moveTailDown
    dec ax
    jz moveTailUp
returnSnakeTail:
    mov al, 0                   ; black
    mov [si], al                ; write to screen
    ret

saveTailMove:
    mov [tailX], bx             ; store the new tail X
    mov [tailY], dl             ; store the new tail Y
    jmp returnSnakeTail

moveTailUp:
    sub dl, 1
    jnc saveTailMove
    mov dl, screenHeight - 1
    jmp saveTailMove

moveTailDown:
    inc dx                      ; saves a byte by incrementing the whole register
    cmp dl, screenHeight + 1
    jne saveTailMove
    mov dl, 0
    jmp saveTailMove

moveTailLeft:
    sub bx, 1
    jnc saveTailMove
    mov bx, screenWidth - 1
    jmp saveTailMove

moveTailRight:
    inc bx
    cmp bx, screenWidth
    jne saveTailMove
    xor bx, bx
    jmp saveTailMove



moveHead:
    mov bx, [headX]             ; load the head X in bx (needs 16 bits)
    mov dl, [headY]             ; load the head Y in dl (only needs 8 bits)
    mov ah, [currentDirection]
retryMoveHead:
    cmp ah, up
    je moveHeadUp
    cmp ah, down
    je moveHeadDown
    cmp ah, left
    je moveHeadLeft
    cmp ah, right
    je moveHeadRight
    
    mov ah, [lastDirection]
    jmp retryMoveHead

saveHeadMove:
    mov [lastDirection], ah
    mov [headX], bx             ; store the new head X
    mov [headY], dl             ; store the new head Y
    ret



moveHeadUp:
    mov al, upBodyColour
    sub dl, 1
    jnc saveHeadMove
    mov dl, screenHeight - 1
    jmp saveHeadMove

moveHeadDown:
    mov al, downBodyColour
    inc dx                      ; saves a byte by incrementing the whole register
    cmp dl, screenHeight + 1
    jne saveHeadMove
    mov dl, 0
    jmp saveHeadMove

moveHeadLeft:
    mov al, leftBodyColour
    sub bx, 1
    jnc saveHeadMove
    mov bx, screenWidth - 1
    jmp saveHeadMove

moveHeadRight:
    mov al, rightBodyColour
    inc bx
    cmp bx, screenWidth
    jne saveHeadMove
    xor bx, bx
    jmp saveHeadMove


setDiToHead:
    mov ax, [headY]
    mov dx, screenWidth         ; equal to the number of pixels per row
    mul dx                      ; multiplies AX and DX to get to headY in screen memory
    add ax, [headX]             ; moves along the row to get to headX in screen memory
    mov di, ax                  ; sets DI to point to the current pixel
    ret                         ; useful if you need to do a conditional return



; If you want to fill the whole 512 byte sector you can enable this
;%define fill_sector


%ifdef fill_sector
times 510-($-$$) db 0
dw 0xaa55                       ; x86 is little endian, so this is actually 0x55, 0xaa
%endif