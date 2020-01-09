; Example to print hello world to the screen from the BIOS
;
; Can be used with:
;   nasm -f bin hello_world_uncommented.asm -o hello_world.img
;   qemu-system-x86_64 -hda hello_world.img
;

bits 16 
org 0x7c00 

blockWidth: equ 10

oldTime: dw 0x0000
startx: dw 0x0000
starty: dw 0x0000


    mov ax, 0x0012          ; 00 = set video mode, 12 = 640x480 16 color graphics
    int 0x10                ; call bios video services
    
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
    cmp dx, [old_time]       ; Wait for change
    je in22
    mov [old_time], dx       ; Save new current time

    hlt        

times 510-($-$$) db 0
dw 0xaa55
