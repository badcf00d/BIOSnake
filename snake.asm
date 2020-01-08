; Example to print hello world to the screen from the BIOS
;
; Can be used with:
;   nasm -f bin hello_world_uncommented.asm -o hello_world.img
;   qemu-system-x86_64 -hda hello_world.img
;

bits 16 
org 0x7c00 

blockWidth: equ 10

    mov si, msg             ; source index to our string
    mov ax, 0x0012          ; 00 = set video mode, 12 = 640x480 16 color graphics
    int 0x10                ; call bios video services
    
    mov cx, 20              ; x
    mov dx, 40              ; y
    push dx
    push cx                 ; stack is now: start y, start x

drawBlock:
    mov bx, 0
    mov ah, 0x0c            ; bios video mode for writing graphics pixels
    mov al, 9               ; bios color attributes
    jmp drawBlockLoop

saveLocationA:
    sub ax, blockWidth
    push ax
    jmp drawBlock           ; stack is now: start y, start x

saveLocationB:
    sub ax, blockWidth      ; reset to start x
    sub bx, blockWidth      ; reset to start y
    sub cx, blockWidth      ; move back to start of column
    push bx
    push ax
    jmp drawBlock           ; stack is now: start y, start x

drawBlockLoop:
    int 0x10                ; draw

    inc cx                  ; move right
    pop ax                  ; stack is now: start y
    add ax, blockWidth      ; block width
    cmp cx, ax              ; end x
    jne saveLocationA

    inc dx                  ; move down, our end x is still in ax
    pop bx                  ; our start y is now in bx
    add bx, blockWidth      ; block width
    cmp dx, bx              ; end y
    jne saveLocationB

    hlt        

times 510-($-$$) db 0
dw 0xaa55
