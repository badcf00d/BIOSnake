; Example to print hello world to the screen from the BIOS
;
; Can be used with:
;   nasm -f bin snake.asm -o snake.img
;   qemu-system-x86_64 -hda snake.img
;

bits 16 
org 0x7c00 
cpu 8086                    ; only 8086 instructions are supported in BIOS

blockWidth: equ 10
screenWidth: equ 320
up: equ 0x77                ; w
down: equ 0x73              ; s
left: equ 0x61              ; a
right: equ 0x64             ; d

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

    mov ax, 0xa000
    mov ds, ax                  ; goes to data segment 0xa0000
    mov es, ax                  ; goes to 0xfa00 within 0xa0000

    mov ax, 20                  ; start x
    mov [headX], ax             ; store start x
    mov [tailX], ax
    mov ax, 40                  ; start y
    mov [headY], ax             ; store start y
    mov [tailY], ax
    call setDiToHead

    mov al, 7                   ; start at grey
    mov [currentColour], al     ; store current colour
    mov al, down                ; start going down
    mov [currentDirection], al  ; store current direction
    mov ax, 1                   ; start with a length of 1
    mov [length], ax            ; store start length




delayUntilTick:
    mov ah, 0x00                ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    mov cl, 3                   ; shift by 3 = divide by 8
    shr dx, cl                  ; divide by 8 = ~2Hz
    cmp dx, [oldTime]           ; Wait for change
    je delayUntilTick
    mov [oldTime], dx           ; Save new current time

    mov ax, 0x0100              ; check for keypress
    int 0x16                    ; calls bios keyboard services
    jnz setDirection            ; jump if there is a key waiting
returnSetDirection:

    call moveHead
    call printSnakeToScreen
    call eraseSnakeTail

    jmp delayUntilTick        






setSiToTail:
    mov ax, [tailY]
    mov dx, screenWidth         ; equal to the number of pixels per row
    mul dx                      ; multiplies AX and DX to get to tailY in screen memory
    add ax, [tailX]             ; moves along the row to get to headX in screen memory
    mov si, ax                  ; sets SI to point to the current pixel
    ret

setDiToHead:
    mov ax, [headY]
    mov dx, screenWidth         ; equal to the number of pixels per row
    mul dx                      ; multiplies AX and DX to get to headY in screen memory
    add ax, [headX]             ; moves along the row to get to headX in screen memory
    mov di, ax                  ; sets DI to point to the current pixel
    ret

printSnakeToScreen:
    call setDiToHead
    mov al, [currentColour]
    cmp byte [di], 0
    jnz gameOverManGameOver
    mov [di], al                ; write to screen
    ret

eraseSnakeTail:
    call setSiToTail
    mov al, 0                   ; black
    mov [si], al                ; write to screen

    add si, screenWidth
    cmp byte [si], 0
    jnz moveTailDown
    sub si, screenWidth

    sub si, screenWidth
    cmp byte [si], 0
    jnz moveTailUp
    add si, screenWidth

    add si, 1
    cmp byte [si], 0
    jnz moveTailRight
    sub si, 1

    sub si, 1
    cmp byte [si], 0
    jnz moveTailLeft
    add si, 1
    ret

moveTailUp:
    dec word [tailY]
    ret
moveTailDown:
    inc word [tailY]
    ret
moveTailLeft:
    dec word [tailX]
    ret
moveTailRight:
    inc word [tailX]
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
; up:    0111 0111  (w)
; down:  0111 0011  (s)
; left:  0110 0001  (a)
; right: 0110 0100  (d)
;   if (al AND 0001 0000) XOR (currentDirection AND 0001 0000) is zero, ignore the key

    mov ah, al
    mov bl, [currentDirection]
    and ah, 0b0001_0000
    and bl, 0b0001_0000
    xor ah, bl
    jz returnSetDirection

    mov [currentDirection], al
    call moveHead
    call printSnakeToScreen
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
    dec word [headY]
    ret
moveHeadDown:
    inc word [headY]
    ret
moveHeadLeft:
    dec word [headX]
    ret
moveHeadRight:
    inc word [headX]
    ret



gameOverManGameOver:
    mov al, 12                  ; red
    mov [di], al                ; Write to screen
    jmp $                       ; loop forever


times 510-($-$$) db 0
dw 0xaa55
