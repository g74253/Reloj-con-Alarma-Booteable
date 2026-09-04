.code16
.intel_syntax noprefix

.section .text

.global bios_clear_screen
.global bios_set_cursor
.global bios_print_string
.global bios_print_char
.global bios_wait_key
.global bios_poll_key
.global bios_read_rtc
.global bios_read_ticks

/* Modo texto 80x25; también limpia la pantalla. */
bios_clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

/* Entrada: DH=fila, DL=columna. */
bios_set_cursor:
    push ax
    push bx
    mov ah, 0x02
    xor bh, bh
    int 0x10
    pop bx
    pop ax
    ret

/* Entrada: DS:SI apunta a una cadena terminada en cero. */
bios_print_string:
    push ax
    push bx
.next_char:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    jmp .next_char
.done:
    pop bx
    pop ax
    ret

/* Entrada: AL=carácter ASCII. */
bios_print_char:
    push bx
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    pop bx
    ret

/* Lectura bloqueante de teclado. Salida: AL=ASCII. */
bios_wait_key:
    xor ah, ah
    int 0x16
    ret

/* Consulta no bloqueante. ZF=1 cuando no hay tecla. */
bios_poll_key:
    mov ah, 0x01
    int 0x16
    ret

/* Hora RTC: CH=hora, CL=minuto y DH=segundo en BCD. */
bios_read_rtc:
    mov ah, 0x02
    int 0x1A
    ret

/*
 * Contador BIOS de aproximadamente 18.2 ticks por segundo.
 * Devuelve EAX = CX:DX para mantener un cronómetro independiente del RTC.
 */
bios_read_ticks:
    xor ah, ah
    int 0x1A
    movzx eax, cx
    shl eax, 16
    mov ax, dx
    ret
