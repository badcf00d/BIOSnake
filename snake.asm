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

bits 16
cpu 8086                    ; only 8086 instructions are supported in BIOS

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
    mov cl, 10                  ; start with a length of 10
    mov [length], cl            ; store start length
    dec cl                      ; cx is the loop counter
    call printSnakeToScreen     ; draw a block at the initial position
initSnake:
    call moveHead
    call printSnakeToScreen     ; draw some initial chunks of the snake
    loop initSnake              ; cx is the loop counter

    



delayUntilTick:
    mov ah, 0x00                ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    mov cl, 1                   ; shift by 2 = divide by 4
    shr dx, cl                  ; divide by 4 = ~4Hz
    cmp dx, [oldTime]           ; wait for change
    je delayUntilTick           ; jump back up if the time is still the same
    mov [oldTime], dx           ; Save new current time

    mov ax, 0x0100              ; check for keypress
    int 0x16                    ; calls bios keyboard services
    jnz setDirection            ; jump if there is a key waiting
returnSetDirection:

    call moveHead
    mov [currentColour], al     ; store current colour
    mov [di], al                ; draw over the old block with the new colour
    call setDiToHead
    call eraseSnakeTail
    call printSnakeToScreen
    call drawFood
    jmp delayUntilTick          ; loop forever




printSnakeToScreen:
    call setDiToHead
    cmp byte [di], upBodyColour
    je gameOverManGameOver
    cmp byte [di], downBodyColour
    je gameOverManGameOver
    cmp byte [di], leftBodyColour
    je gameOverManGameOver
    cmp byte [di], rightBodyColour
    je gameOverManGameOver
    mov al, [currentColour]
    mov [di], al                ; write to screen
    ret



drawFood:
    mov ah, 0x02                ; reads time from RTC
    int 0x1a                    ; call real time clock BIOS Services
    xor cx, dx                  ; xor the low and high bytes of the time
    mov bx, cx                  ; copy this to the bx register
    mov ah, 0x00                ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    xor ax, cx                  ; xor with high word of system tick count
    xor ax, dx                  ; xor with low word of system tick count
    xor ax, 0xd39e              ; xor with a random number
retryDrawFood:
    xor ax, bx                  ; now AX should be a pretty random number
    mov bx, 63999               ; dividing here to make sure we're actually on the screen
    div bx                      ; divides AX by BX, puts remainder in DX

    mov di, dx                  ; take the remainder of our division and put it in DI
    cmp byte [di], 0            ; check if that pixel has already been drawn to
    jne retryDrawFood           ; try scramble the numbers again

    mov cl, foodColour
    mov [di], cl                ; draw to the screen
    call setDiToHead            ; set DI back to where it should be
    ret 
    
    


eraseSnakeTail:
    cmp byte [di], foodColour   ; is the head on a piece of food?
    je jumpToReturn             ; if we're about to eat food, don't erase the tail
    call setSiToTail

    cmp byte [si], upBodyColour
    je moveTailUp
    cmp byte [si], downBodyColour
    je moveTailDown
    cmp byte [si], leftBodyColour
    je moveTailLeft
    cmp byte [si], rightBodyColour
    je moveTailRight
returnSnakeTail:
    mov al, 0                   ; black
    mov [si], al                ; write to screen
    ret


setSiToTail:
    mov ax, [tailY]
    mov dx, screenWidth         ; equal to the number of pixels per row
    mul dx                      ; multiplies AX and DX to get to tailY in screen memory
    add ax, [tailX]             ; moves along the row to get to tailX in screen memory
    mov si, ax                  ; sets SI to point to the current pixel
    ret

setDiToHead:
    mov ax, [headY]
    mov dx, screenWidth         ; equal to the number of pixels per row
    mul dx                      ; multiplies AX and DX to get to headY in screen memory
    add ax, [headX]             ; moves along the row to get to headX in screen memory
    mov di, ax                  ; sets DI to point to the current pixel
    ret




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



moveHead:
    cmp byte [currentDirection], up
    je moveHeadUp
    cmp byte [currentDirection], down
    je moveHeadDown
    cmp byte [currentDirection], left
    je moveHeadLeft
    cmp byte [currentDirection], right
    je moveHeadRight    




moveHeadUp:
    mov al, upBodyColour
    cmp word [headY], 0
    dec word [headY]
    jnz jumpToReturn
    mov bx, screenHeight
    mov [headY], bx
    ret
moveHeadDown:
    mov al, downBodyColour
    inc word [headY]
    cmp word [headY], screenHeight
    jne jumpToReturn
    mov bx, 0
    mov [headY], bx
    ret
moveHeadLeft:
    mov al, leftBodyColour
    dec word [headX]
    jnz jumpToReturn
    mov bx, screenHeight
    mov [headY], bx
    ret
moveHeadRight:
    mov al, rightBodyColour
    inc word [headX]
    ret

moveTailUp:
    dec word [tailY]
    jmp returnSnakeTail
moveTailDown:
    inc word [tailY]
    jmp returnSnakeTail
moveTailLeft:
    dec word [tailX]
    jmp returnSnakeTail
moveTailRight:
    inc word [tailX]
    jmp returnSnakeTail


jumpToReturn:
    ret                         ; useful if you need to do a conditional return


gameOverManGameOver:
    mov al, 12                  ; red
    mov [di], al                ; Write to screen
    jmp $                       ; loop forever


times 510-($-$$) db 0
dw 0xaa55
