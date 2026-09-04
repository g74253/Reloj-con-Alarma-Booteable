.code16
.intel_syntax noprefix

.section .text

.global ui_show_confirmation
.global ui_draw_static
.global ui_render_dynamic
.global ui_show_goodbye

.extern bios_set_cursor
.extern bios_print_string
.extern bios_print_char
.extern rtc_valid
.extern rtc_hour
.extern rtc_minute
.extern rtc_second
.extern current_mode
.extern stopwatch_running
.extern sw_display_hour
.extern sw_display_minute
.extern sw_display_second

/* DH=fila, DL=columna, DS:SI=cadena. */
print_at:
    call bios_set_cursor
    call bios_print_string
    ret

ui_show_confirmation:
    mov dh, 7
    mov dl, 16
    mov si, OFFSET confirm_title
    call print_at
    mov dh, 10
    mov dl, 12
    mov si, OFFSET confirm_question
    call print_at
    mov dh, 12
    mov dl, 17
    mov si, OFFSET confirm_keys
    call print_at
    ret

ui_draw_static:
    mov dh, 2
    mov dl, 17
    mov si, OFFSET title
    call print_at
    mov dh, 14
    mov dl, 7
    mov si, OFFSET controls_1
    call print_at
    mov dh, 15
    mov dl, 19
    mov si, OFFSET controls_2
    call print_at
    mov dh, 17
    mov dl, 33
    mov si, OFFSET exit_help
    call print_at
    mov dh, 21
    mov dl, 11
    mov si, OFFSET bios_note
    call print_at
    ret

ui_render_dynamic:
    /* Limpiar y volver a escribir el indicador del modo activo. */
    mov dh, 5
    mov dl, 25
    mov si, OFFSET mode_line_spaces
    call print_at
    mov dh, 5
    mov dl, 25
    cmp BYTE PTR [current_mode], 0
    jne .show_stopwatch_mode
    mov si, OFFSET mode_clock
    call print_at
    jmp .show_clock

.show_stopwatch_mode:
    mov si, OFFSET mode_stopwatch
    call print_at
    jmp .show_stopwatch

.show_clock:
    mov dh, 9
    mov dl, 24
    mov si, OFFSET display_line_spaces
    call print_at
    mov dh, 9
    mov dl, 26
    mov si, OFFSET clock_label
    call print_at
    mov dh, 9
    mov dl, 38
    call bios_set_cursor
    cmp BYTE PTR [rtc_valid], 0
    je .unavailable

    mov al, BYTE PTR [rtc_hour]
    call print_bcd2
    mov al, ':'
    call bios_print_char
    mov al, BYTE PTR [rtc_minute]
    call print_bcd2
    mov al, ':'
    call bios_print_char
    mov al, BYTE PTR [rtc_second]
    call print_bcd2
    call clear_stopwatch_state
    ret

.unavailable:
    mov si, OFFSET no_time
    call bios_print_string
    call clear_stopwatch_state
    ret

.show_stopwatch:
    mov dh, 9
    mov dl, 24
    mov si, OFFSET display_line_spaces
    call print_at
    mov dh, 9
    mov dl, 24
    mov si, OFFSET stopwatch_label
    call print_at
    mov dh, 9
    mov dl, 38
    call bios_set_cursor
    mov al, BYTE PTR [sw_display_hour]
    call print_decimal2
    mov al, ':'
    call bios_print_char
    mov al, BYTE PTR [sw_display_minute]
    call print_decimal2
    mov al, ':'
    call bios_print_char
    mov al, BYTE PTR [sw_display_second]
    call print_decimal2

    mov dh, 11
    mov dl, 31
    cmp BYTE PTR [stopwatch_running], 0
    je .show_paused
    mov si, OFFSET stopwatch_active
    call print_at
    ret
.show_paused:
    mov si, OFFSET stopwatch_paused
    call print_at
    ret

clear_stopwatch_state:
    mov dh, 11
    mov dl, 31
    mov si, OFFSET state_spaces
    call print_at
    ret

ui_show_goodbye:
    mov dh, 9
    mov dl, 18
    mov si, OFFSET goodbye_1
    call print_at
    mov dh, 11
    mov dl, 10
    mov si, OFFSET goodbye_2
    call print_at
    ret

/* Convierte un byte BCD en dos caracteres decimales. */
print_bcd2:
    push ax
    push dx
    mov dl, al
    shr al, 4
    and al, 0x0F
    add al, '0'
    call bios_print_char
    mov al, dl
    and al, 0x0F
    add al, '0'
    call bios_print_char
    pop dx
    pop ax
    ret

/* Convierte un valor binario de 0 a 99 en dos caracteres. */
print_decimal2:
    push ax
    push bx
    push dx
    xor ah, ah
    mov bl, 10
    div bl
    mov dl, ah
    add al, '0'
    call bios_print_char
    mov al, dl
    add al, '0'
    call bios_print_char
    pop dx
    pop bx
    pop ax
    ret

.section .rodata
confirm_title:    .asciz "TAREA 1: RELOJ/CRONOMETRO CON ALARMA"
confirm_question: .asciz "Deseas iniciar la aplicacion interactiva?"
confirm_keys:     .asciz "[S] Si                         [N] No"
title:            .asciz "TAREA 1: RELOJ/CRONOMETRO CON ALARMA"
mode_clock:       .asciz "[ MODO 1: RELOJ ]"
mode_stopwatch:   .asciz "[ MODO 2: CRONOMETRO ]"
clock_label:      .asciz "Hora RTC:"
stopwatch_label:  .asciz "Cronometro:"
no_time:          .asciz "--:--:--"
exit_help:        .asciz "[Q] Finalizar"
bios_note:        .asciz "Hora obtenida con BIOS / RTC"
controls_1:       .asciz "[M] Cambiar modo     [S] Iniciar/Pausar/Reanudar"
controls_2:       .asciz "[R] Reiniciar cronometro"
stopwatch_active: .asciz "EN MARCHA"
stopwatch_paused: .asciz "PAUSADO  "
mode_line_spaces: .asciz "                              "
display_line_spaces: .asciz "                                "
state_spaces:     .asciz "          "
goodbye_1:        .asciz "Aplicacion finalizada correctamente."
goodbye_2:        .asciz "El procesador esta detenido. Reinicie el equipo cuando desee."
