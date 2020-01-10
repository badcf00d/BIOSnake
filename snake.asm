; Example to print hello world to the screen from the BIOS
;
; Can be used with:
;   nasm -f bin hello_world_uncommented.asm -o hello_world.img
;   qemu-system-x86_64 -hda hello_world.img
;

bits 16 
org 0x7c00 
cpu 8086                    ; only 8086 instructions are supported in BIOS

blockWidth: equ 10
screenWidth: equ 320
up: equ 0x77
down: equ 0x73
left: equ 0x61
right: equ 0x64

; within data segment 0xa0000 - 0xaffff:
;
;   0x0000 - 0xf9ff is the visible screen graphics (320x200 = 0xfa00 = 64000 bytes)
;   0xfa00 - fxffff is free real estate (1535 bytes)

xCord: equ 0xfa00
yCord: equ 0xfa02
oldTime: equ 0xfa04
currentColour: equ 0xfa06
currentDirection: equ 0xf807

    mov ax, 0x0013              ; 00 = set video mode, 13 = 320x200 8-bit colour
    int 0x10                    ; call bios video services

    mov ax, 0xa000
    mov ds, ax                  ; goes to data segment 0xa0000
    mov es, ax                  ; goes to 0xfa00 within 0xa0000

    mov ax, 20                  ; start x
    mov [xCord], ax             ; store start x
    mov ax, 40                  ; start y
    mov [yCord], ax             ; store start y
    mov al, 9                   ; start at colour 0
    mov [currentColour], al     ; store current colour
    mov al, down                ; start going down
    mov [currentDirection], al  ; store current direction

delayUntilTick:
    mov ah, 0x01                ; get key-press
    int 0x16                    ; calls bios keyboard services
    jmp setDirection 
returnSetDirection:
    mov [0xf907], al
    mov ah,0x00                 ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                    ; call real time clock BIOS Services
    mov cl, 1                   ; shift by 3 = divide by 8
    shr dx, cl                  ; divide by 8 = ~2Hz
    cmp dx, [oldTime]           ; Wait for change
    je delayUntilTick

    mov [oldTime], dx           ; Save new current time
    jmp moveCord
returnMoveCord:

    mov ax, [yCord]
    mov dx, screenWidth         ; equal to the number of pixels per row
    mul dx                      ; multiplies AX and DX to get to yCord in screen memory
    add ax, [xCord]             ; moves along the row to get to xCord in screen memory
    mov di, ax                  ; sets DI to point to the current pixel ready for stosb

    mov al, [currentColour]
    mov [di], al                       
    inc byte [currentColour]

    jmp delayUntilTick        


setDirection:
    cmp al, up
    je validKey
    cmp al, down
    je validKey
    cmp al, left
    je validKey
    cmp al, right
    je validKey
    jmp returnSetDirection

validKey:
    mov [currentDirection], al
    jmp returnSetDirection




moveCord:
    cmp byte [currentDirection], up
    je moveUp
    cmp byte [currentDirection], down
    je moveDown
    cmp byte [currentDirection], left
    je moveLeft
    cmp byte [currentDirection], right
    je moveRight

moveUp:
    dec word [yCord]
    jmp returnMoveCord
moveDown:
    inc word [yCord]
    jmp returnMoveCord
moveLeft:
    dec word [xCord]
    jmp returnMoveCord
moveRight:
    inc word [xCord]
    jmp returnMoveCord

times 510-($-$$) db 0
dw 0xaa55
