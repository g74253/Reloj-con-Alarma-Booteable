.code16
.intel_syntax noprefix

.section .text

.global ui_show_confirmation
.global ui_draw_static
.global ui_render_dynamic
.global ui_show_alarm_prompt
.global ui_show_invalid_alarm
.global ui_clear_status
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
.extern alarm_enabled
.extern alarm_ringing
.extern alarm_phase
.extern alarm_hour
.extern alarm_minute

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
    mov dh, 16
    mov dl, 19
    mov si, OFFSET controls_3
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
    jmp render_alarm

.unavailable:
    mov si, OFFSET no_time
    call bios_print_string
    call clear_stopwatch_state
    jmp render_alarm

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
    jmp render_alarm
.show_paused:
    mov si, OFFSET stopwatch_paused
    call print_at
    jmp render_alarm

clear_stopwatch_state:
    mov dh, 11
    mov dl, 31
    mov si, OFFSET state_spaces
    call print_at
    ret

/* Estado persistente y aviso visual de la alarma. */
render_alarm:
    mov dh, 12
    mov dl, 20
    mov si, OFFSET alarm_line_spaces
    call print_at
    mov dh, 12
    mov dl, 20
    mov si, OFFSET alarm_label
    call print_at

    cmp BYTE PTR [alarm_ringing], 0
    jne .alarm_is_ringing
    cmp BYTE PTR [alarm_enabled], 0
    je .alarm_is_off

    mov al, BYTE PTR [alarm_hour]
    call print_bcd2
    mov al, ':'
    call bios_print_char
    mov al, BYTE PTR [alarm_minute]
    call print_bcd2
    mov si, OFFSET alarm_configured
    call bios_print_string
    jmp .render_banner

.alarm_is_ringing:
    mov si, OFFSET alarm_ringing_text
    call bios_print_string
    jmp .render_banner

.alarm_is_off:
    mov si, OFFSET alarm_off
    call bios_print_string

.render_banner:
    mov dh, 7
    mov dl, 31
    mov si, OFFSET banner_spaces
    call print_at
    cmp BYTE PTR [alarm_ringing], 0
    je .alarm_render_done
    cmp BYTE PTR [alarm_phase], 0
    je .alarm_render_done
    mov dh, 7
    mov dl, 31
    mov si, OFFSET alarm_banner
    call print_at
.alarm_render_done:
    ret

ui_show_alarm_prompt:
    call ui_clear_status
    mov dh, 19
    mov dl, 3
    mov si, OFFSET alarm_prompt
    call print_at
    ret

ui_show_invalid_alarm:
    call ui_clear_status
    mov dh, 19
    mov dl, 8
    mov si, OFFSET invalid_alarm
    call print_at
    ret

ui_clear_status:
    mov dh, 19
    mov dl, 0
    mov si, OFFSET status_spaces
    call print_at
    mov dh, 20
    mov dl, 0
    mov si, OFFSET status_spaces
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
controls_1:       .asciz "[M] Cambiar modo      [S] Iniciar/Pausar/Reanudar"
controls_2:       .asciz "[R] Reiniciar cronometro"
controls_3:       .asciz "[A] Configurar alarma      [C] Cancelar alarma"
stopwatch_active: .asciz "EN MARCHA"
stopwatch_paused: .asciz "PAUSADO  "
mode_line_spaces: .asciz "                              "
display_line_spaces: .asciz "                                "
state_spaces:     .asciz "          "
alarm_label:      .asciz "Alarma: "
alarm_configured: .asciz "  configurada"
alarm_ringing_text: .asciz "SONANDO - C para cancelar"
alarm_off:        .asciz "desactivada"
alarm_banner:     .asciz "*** ALARMA ***"
banner_spaces:    .asciz "              "
alarm_line_spaces: .asciz "                                        "
alarm_prompt:     .asciz "Nueva alarma HH:MM (ESC conserva la actual): "
invalid_alarm:    .asciz "Hora invalida. Use 00:00 a 23:59. Presione una tecla."
status_spaces:    .asciz "                                                                                "
goodbye_1:        .asciz "Aplicacion finalizada correctamente."
goodbye_2:        .asciz "El procesador esta detenido. Reinicie el equipo cuando desee."
