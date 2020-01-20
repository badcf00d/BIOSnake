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

foodColour: equ 9           ; light blue
tailColour: equ 5           ; magenta
upBodyColour: equ 31        ; white
downBodyColour: equ 30      ; slightly less white
leftBodyColour: equ 29      ; slightly more less white
rightBodyColour: equ 28     ; even more less white

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


start:
    mov ax, 0x0013              ; 00 = set video mode, 13 = 320x200 8-bit colour
    int 0x10                    ; call bios video services

    mov cx, 0xa000
    mov ds, cx                  ; goes to data segment 0xa0000
    mov es, cx                  ; goes to 0xfa00 within 0xa0000

    mov cx, 20                  ; start x
    mov [headX], cl             ; store start x
    mov [tailX], cl             ; store tail x
    mov cl, 40                  ; start y
    mov [headY], cl             ; store start y
    mov [tailY], cl             ; store tail y

    mov cl, down                ; start going down
    mov [currentDirection], cl  ; store current direction
    mov cl, downBodyColour      ; start at grey
    mov [currentColour], cl     ; store current colour
    mov cl, 10                  ; cx is the loop counter
    mov [length], cx
    dec cx
    call printSnakeToScreen     ; draw a block at the initial position
initSnake:
    call moveHead
    call printSnakeToScreen     ; draw some initial chunks of the snake
    loop initSnake              ; cx is the loop counter
    call drawFood
    



delayUntilTick:
    mov ah, 0x00                ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    shr dx, 1                   ; divide by 2 = ~9Hz
    cmp dx, [oldTime]           ; wait for change
    je delayUntilTick           ; jump back up if the time is still the same
    mov [oldTime], dx           ; Save new current time

    mov ah, 0x01                ; check for keypress
    int 0x16                    ; calls bios keyboard services
    jnz setDirection            ; jump if there is a key waiting
returnSetDirection:

    call moveHead
    mov [currentColour], al     ; store current colour
    mov [di], al                ; draw over the old block with the new colour
    call setDiToHead
    call eraseSnakeTail
    call printSnakeToScreen

    mov ax, [oldTime]           ; only draw food every 100 ticks
    mov bx, 100
    div bx
    cmp dx, 0
    jne delayUntilTick
    call drawFood
    jmp delayUntilTick          ; loop forever




setDirection:
    mov ah, 0x00                ; fetches the keystroke from the keyboard buffer
    int 0x16                    ; call bios keyboard services
    cmp al, up
    je validKey
    cmp al, down
    je validKey
    cmp al, left
    je validKey
    cmp al, right
    je validKey
    jmp returnSetDirection      ; if we get here, it was an invalid key, don't save it

validKey:
; we can stop the snake from going back into itself by doing this check
;
; up:    0111 0111  (w)
; down:  0111 0011  (s)
; left:  0110 0001  (a)
; right: 0110 0100  (d)
;   if (al AND 0001 0000) XOR (currentDirection AND 0001 0000) is zero, ignore the key

    mov ah, al                  ; AL contains the key that was pressed
    mov bl, [currentDirection]
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
    mov ax, 0x0003              ; 00 = set video mode, 03 = 80x25 8-bit colour text
    int 0x10                    ; call bios video services


    xor dx, dx
    mov es, dx
    mov ax, 0x1301              ; write string mode for bios video services, write mode 1, increment cursor & attributes in BL
    mov bl, 7                   ; BIOS color attributes, 7 is light gray, low nibble is forground, high is background
    mov dx, 0x0A0A              ; row, column
    mov bp, endMessage          ; base pointer to string
    mov cx, endMessageLen       ; length of string
    int 0x10                    ; call bios video services

    add dx, endMessageLen + 10
    mov ah, 0x02
    int 0x10

    mov bx, 100

writeScore:
    xor dx, dx
    mov ax, bx
    mov cx, 10
    div cx
    mov bx, ax
    mov al, dl
    add al, 0x30                ; 0x30 = "0"

    mov ah, 0x03
    int 0x10
    dec dl
    mov ah, 0x0e
    int 0x10

    mov ah, 0x02
    int 0x10

    cmp bx, 0
    jnz writeScore

    jmp $                       ; loop here forever


drawFood:
    mov ah, 0x02                ; reads time from RTC
    int 0x1a                    ; call real time clock BIOS Services
    xor ax, dx                  ; xor the low and high bytes of the time
    xor ax, cx
    xor ax, 0xd39e              ; xor with a random number
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
    
    
ateFood:
    inc word [length]
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
    mov al, [currentDirection]
    cmp al, up
    je moveHeadUp
    cmp al, down
    je moveHeadDown
    cmp al, left
    je moveHeadLeft
    cmp al, right
    je moveHeadRight

saveHeadMove:
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



endMessage: db "Score: "
endMessageLen: equ $ - endMessage
times 510-($-$$) db 0
dw 0xaa55                       ; x86 is little endian, so this is actually 0x55, 0xaa
