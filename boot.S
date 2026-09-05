.code16
.intel_syntax noprefix

.section .text
.global _boot_start

/*
 * Sector de arranque Legacy BIOS.
 * BIOS lo carga en 0000:7C00. Carga la aplicacion desde los 16 sectores
 * siguientes hacia 1000:0000 y transfiere el control con RETF.
 */
_boot_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld

    mov BYTE PTR [boot_drive], dl

    mov si, OFFSET welcome_msg
    call print_string

    /* Leer sectores 2..17 (CHS 0/0/2) en 1000:0000. */
    mov bp, 3
.load_retry:
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 16
    xor ch, ch
    mov cl, 2
    xor dh, dh
    mov dl, BYTE PTR [boot_drive]
    int 0x13
    jnc .loaded

    /* Reiniciar el controlador de disco y reintentar. */
    xor ah, ah
    mov dl, BYTE PTR [boot_drive]
    int 0x13
    dec bp
    jnz .load_retry

    mov si, OFFSET disk_error_msg
    call print_string
    jmp halt_forever

.loaded:
    mov si, OFFSET loaded_msg
    call print_string

    /* Salto lejano a CS:IP = 1000:0000. */
    push 0x1000
    push 0x0000
    retf

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    jmp print_string
.done:
    ret

halt_forever:
    cli
.halt:
    hlt
    jmp .halt

boot_drive:
    .byte 0

welcome_msg:
    .asciz "\r\nCE 4303 - Reloj/Cronometro con Alarma\r\nBootloader BIOS iniciado. Cargando aplicacion...\r\n"
loaded_msg:
    .asciz "Aplicacion cargada correctamente.\r\n"
disk_error_msg:
    .asciz "ERROR: no se pudo leer la aplicacion.\r\n"

/* Firma obligatoria del sector de arranque. */
.org 510
.byte 0x55, 0xAA
