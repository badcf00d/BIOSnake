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


; within data segment 0xa0000 - 0xaffff:
;
;   0x0000 - 0xf9ff is the visible screen graphics (320x200 = 0xfa00 = 64000 bytes)
;   0xfa00 - fxffff is free real estate (1535 bytes)

xCord: equ 0xfa00
yCord: equ 0xfa02
oldTime: equ 0xfa04

    mov ax, 0x0013          ; 00 = set video mode, 13 = 320x200 8-bit colour
    int 0x10                ; call bios video services

    mov ax, 0xa000
    mov ds, ax              ; goes to data segment 0xa0000
    mov es, ax              ; goes to 
    
    mov cx, 20              ; start x
    mov dx, 40              ; start y
    push dx                 ; stack is now: start y
    push cx                 ; stack is now: start y, start x
    jmp drawBlock

restoreStartX:
    sub ax, blockWidth      ; reset to start x
    push ax                 ; stack is now: start y, start x
    jmp drawBlock

restoreStartXAndY:
    sub ax, blockWidth      ; reset to start x
    sub bx, blockWidth      ; reset to start y
    sub cx, blockWidth      ; reset to start x
    push bx                 ; stack is now: start y
    push ax                 ; stack is now: start y, start x

drawBlock:
    mov bx, 0               ; video page 0
    mov ah, 0x0c            ; bios video mode for writing graphics pixels
    mov al, 7               ; bios color attributes, light gray

drawBlockLoop:
    int 0x10                ; call bios video services

    inc cx                  ; move right
    pop ax                  ; stack is now: start y
    add ax, blockWidth      ; move to end x
    cmp cx, ax              ; are we done?
    jne restoreStartX

    inc dx                  ; move down, our end x is still in ax
    pop bx                  ; our start y is now in bx
    add bx, blockWidth      ; move to end y
    cmp dx, bx              ; are we done?
    jne restoreStartXAndY

delayUntilTick:
    mov ah,0x00             ; reads system tick counter (~18 Hz) into cx and dx
    int 0x1a                ; Call real time clock BIOS Services
    shr dx, 3               ; divide by 8 = ~2Hz
    cmp dx, [oldTime]       ; Wait for change
    je delayUntilTick
    mov [oldTime], dx       ; Save new current time

    mov ah, 0x00            ; waits for a keypress
    int 0x16                ; calls bios keyboard services

    mov ax, 0x0002          ; set video mode to 80x25 text
    int 0x10                ; calls bios video services
    
    hlt        

times 510-($-$$) db 0
dw 0xaa55
