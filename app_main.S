.code16
.intel_syntax noprefix

.section .text.entry
.global _app_start

.extern bios_clear_screen
.extern bios_wait_key
.extern bios_poll_key
.extern bios_read_rtc
.extern ui_show_confirmation
.extern ui_draw_static
.extern ui_render_clock
.extern ui_show_goodbye

.global rtc_valid
.global rtc_hour
.global rtc_minute
.global rtc_second

/* Incremento 1: aplicación booteable con reloj RTC. */
_app_start:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x9000
    mov ss, ax
    mov sp, 0xFFFE
    sti
    cld

    call bios_clear_screen
    call ui_show_confirmation

.confirmation_loop:
    call bios_wait_key
    cmp al, 'S'
    je .confirmed
    cmp al, 's'
    je .confirmed
    cmp al, 'N'
    je finish_program
    cmp al, 'n'
    je finish_program
    cmp al, 'Q'
    je finish_program
    cmp al, 'q'
    je finish_program
    jmp .confirmation_loop

.confirmed:
    call bios_clear_screen
    call ui_draw_static
    mov BYTE PTR [last_rtc_second], 0xFF

main_loop:
    /* INT 1Ah/AH=02h devuelve CH:CL:DH = HH:MM:SS en BCD. */
    call bios_read_rtc
    jc .rtc_error

    mov BYTE PTR [rtc_valid], 1
    mov BYTE PTR [rtc_hour], ch
    mov BYTE PTR [rtc_minute], cl
    mov BYTE PTR [rtc_second], dh

    /* Redibujar únicamente cuando cambia el segundo. */
    cmp dh, BYTE PTR [last_rtc_second]
    je .check_keyboard
    mov BYTE PTR [last_rtc_second], dh
    call ui_render_clock
    jmp .check_keyboard

.rtc_error:
    cmp BYTE PTR [rtc_valid], 0
    je .check_keyboard
    mov BYTE PTR [rtc_valid], 0
    call ui_render_clock

.check_keyboard:
    call bios_poll_key
    jz main_loop
    call bios_wait_key
    cmp al, 'Q'
    je finish_program
    cmp al, 'q'
    je finish_program
    jmp main_loop

finish_program:
    call bios_clear_screen
    call ui_show_goodbye
    cli
.halt_forever:
    hlt
    jmp .halt_forever

.section .data
rtc_valid:       .byte 0
rtc_hour:        .byte 0
rtc_minute:      .byte 0
rtc_second:      .byte 0
last_rtc_second: .byte 0xFF
