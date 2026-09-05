.code16
.intel_syntax noprefix

.section .text.entry
.global _app_start

.extern bios_clear_screen
.extern bios_wait_key
.extern bios_poll_key
.extern bios_read_rtc
.extern bios_read_ticks
.extern bios_beep
.extern bios_print_char
.extern ui_show_confirmation
.extern ui_draw_static
.extern ui_render_dynamic
.extern ui_show_alarm_prompt
.extern ui_show_invalid_alarm
.extern ui_clear_status
.extern ui_show_goodbye

.global current_mode
.global rtc_valid
.global rtc_hour
.global rtc_minute
.global rtc_second
.global stopwatch_running
.global sw_display_hour
.global sw_display_minute
.global sw_display_second
.global alarm_enabled
.global alarm_ringing
.global alarm_phase
.global alarm_hour
.global alarm_minute

/* Modo 1: aplicacion booteable con reloj RTC. */
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
    call compute_stopwatch_display
    call ui_render_dynamic
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
    call update_alarm
    call compute_stopwatch_display

    cmp BYTE PTR [alarm_ringing], 0
    je .render
    xor BYTE PTR [alarm_phase], 1
    call bios_beep
.render:
    call ui_render_dynamic
    jmp .check_keyboard

.rtc_error:
    cmp BYTE PTR [rtc_valid], 0
    je .check_keyboard
    mov BYTE PTR [rtc_valid], 0
    call ui_render_dynamic

.check_keyboard:
    call bios_poll_key
    jz main_loop
    call bios_wait_key
    cmp al, 'M'
    je toggle_mode
    cmp al, 'm'
    je toggle_mode
    cmp al, 'S'
    je toggle_stopwatch
    cmp al, 's'
    je toggle_stopwatch
    cmp al, 'R'
    je reset_stopwatch
    cmp al, 'r'
    je reset_stopwatch
    cmp al, 'A'
    je configure_alarm
    cmp al, 'a'
    je configure_alarm
    cmp al, 'C'
    je cancel_alarm
    cmp al, 'c'
    je cancel_alarm
    cmp al, 'Q'
    je finish_program
    cmp al, 'q'
    je finish_program
    jmp main_loop

/* M alterna entre el reloj RTC y el cronómetro. */
toggle_mode:
    xor BYTE PTR [current_mode], 1
    call compute_stopwatch_display
    call ui_render_dynamic
    jmp main_loop

/* S inicia, pausa o reanuda el cronometro. */
toggle_stopwatch:
    cmp BYTE PTR [stopwatch_running], 0
    jne .pause_stopwatch

    call bios_read_ticks
    mov DWORD PTR [sw_start_ticks], eax
    mov BYTE PTR [stopwatch_running], 1
    call compute_stopwatch_display
    call ui_render_dynamic
    jmp main_loop

.pause_stopwatch:
    call stopwatch_live_delta
    add DWORD PTR [sw_accum_ticks], eax
    mov BYTE PTR [stopwatch_running], 0
    call compute_stopwatch_display
    call ui_render_dynamic
    jmp main_loop

/* R pone el cronometro en cero  */
reset_stopwatch:
    mov DWORD PTR [sw_accum_ticks], 0
    cmp BYTE PTR [stopwatch_running], 0
    je .show_reset
    call bios_read_ticks
    mov DWORD PTR [sw_start_ticks], eax
.show_reset:
    call compute_stopwatch_display
    call ui_render_dynamic
    jmp main_loop

/* C cancela tanto una alarma pendiente como una alarma sonando. */
cancel_alarm:
    mov BYTE PTR [alarm_enabled], 0
    mov BYTE PTR [alarm_ringing], 0
    mov BYTE PTR [alarm_phase], 0
    call ui_clear_status
    call ui_render_dynamic
    jmp main_loop

/* A solicita cuatro dígitos HHMM; ESC conserva la alarma anterior. */
configure_alarm:
    call ui_show_alarm_prompt
    xor bx, bx

.alarm_key_loop:
    call bios_wait_key
    cmp al, 27
    je .alarm_input_cancelled
    cmp al, 'Q'
    je finish_program
    cmp al, 'q'
    je finish_program
    cmp al, '0'
    jb .alarm_key_loop
    cmp al, '9'
    ja .alarm_key_loop

    mov BYTE PTR [alarm_digits + bx], al
    call bios_print_char
    inc bx
    cmp bx, 2
    jne .no_colon
    mov al, ':'
    call bios_print_char
.no_colon:
    cmp bx, 4
    jb .alarm_key_loop

    /* Validar hora binaria: 00..23. */
    mov al, BYTE PTR [alarm_digits]
    sub al, '0'
    mov dl, 10
    mul dl
    mov dl, BYTE PTR [alarm_digits + 1]
    sub dl, '0'
    add al, dl
    cmp al, 23
    ja .invalid_alarm

    /* Validar minuto binario: 00..59. */
    mov al, BYTE PTR [alarm_digits + 2]
    sub al, '0'
    mov dl, 10
    mul dl
    mov dl, BYTE PTR [alarm_digits + 3]
    sub dl, '0'
    add al, dl
    cmp al, 59
    ja .invalid_alarm

    /* Empaquetar HH:MM en BCD para compararlo directamente con el RTC. */
    mov al, BYTE PTR [alarm_digits]
    sub al, '0'
    shl al, 4
    mov ah, BYTE PTR [alarm_digits + 1]
    sub ah, '0'
    or al, ah
    mov BYTE PTR [alarm_hour], al

    mov al, BYTE PTR [alarm_digits + 2]
    sub al, '0'
    shl al, 4
    mov ah, BYTE PTR [alarm_digits + 3]
    sub ah, '0'
    or al, ah
    mov BYTE PTR [alarm_minute], al

    mov BYTE PTR [alarm_enabled], 1
    mov BYTE PTR [alarm_ringing], 0
    mov BYTE PTR [alarm_phase], 0
    call ui_clear_status
    mov BYTE PTR [last_rtc_second], 0xFF
    jmp main_loop

.invalid_alarm:
    call ui_show_invalid_alarm
    call bios_wait_key
    cmp al, 'Q'
    je finish_program
    cmp al, 'q'
    je finish_program
    call ui_show_alarm_prompt
    xor bx, bx
    jmp .alarm_key_loop

.alarm_input_cancelled:
    call ui_clear_status
    call ui_render_dynamic
    jmp main_loop

/* La alarma es de un solo disparo cuando HH:MM coincide con el RTC. */
update_alarm:
    cmp BYTE PTR [alarm_enabled], 0
    je .alarm_done
    mov al, BYTE PTR [rtc_hour]
    cmp al, BYTE PTR [alarm_hour]
    jne .alarm_done
    mov al, BYTE PTR [rtc_minute]
    cmp al, BYTE PTR [alarm_minute]
    jne .alarm_done
    mov BYTE PTR [alarm_enabled], 0
    mov BYTE PTR [alarm_ringing], 1
    mov BYTE PTR [alarm_phase], 0
.alarm_done:
    ret

finish_program:
    call bios_clear_screen
    call ui_show_goodbye
    cli
.halt_forever:
    hlt
    jmp .halt_forever

/*
 * EAX = ticks transcurridos desde el ultimo inicio
 * El contador BIOS vuelve a cero a medianoche (0x1800B0 ticks).
 */
stopwatch_live_delta:
    call bios_read_ticks
    mov edx, DWORD PTR [sw_start_ticks]
    cmp eax, edx
    jae .no_midnight_wrap
    add eax, 0x001800B0
.no_midnight_wrap:
    sub eax, edx
    ret

/* EAX = ticks acumulados*/
stopwatch_total_ticks:
    cmp BYTE PTR [stopwatch_running], 0
    je .only_accumulated
    call stopwatch_live_delta
    add eax, DWORD PTR [sw_accum_ticks]
    ret
.only_accumulated:
    mov eax, DWORD PTR [sw_accum_ticks]
    ret

/* Convierte los ticks BIOS a HH:MM:SS */
compute_stopwatch_display:
    call stopwatch_total_ticks

    /* 18.2 ticks por segundo: (ticks * 10) / 182. */
    imul eax, eax, 10
    xor edx, edx
    mov ebx, 182
    div ebx

    xor edx, edx
    mov ebx, 3600
    div ebx
    mov ecx, edx

    xor edx, edx
    mov ebx, 100
    div ebx
    mov BYTE PTR [sw_display_hour], dl

    mov eax, ecx
    xor edx, edx
    mov ebx, 60
    div ebx
    mov BYTE PTR [sw_display_minute], al
    mov BYTE PTR [sw_display_second], dl
    ret

.section .data
current_mode:     .byte 0
rtc_valid:       .byte 0
rtc_hour:        .byte 0
rtc_minute:      .byte 0
rtc_second:      .byte 0
last_rtc_second: .byte 0xFF

stopwatch_running: .byte 0
sw_accum_ticks:    .long 0
sw_start_ticks:    .long 0
sw_display_hour:   .byte 0
sw_display_minute: .byte 0
sw_display_second: .byte 0

alarm_enabled: .byte 0
alarm_ringing: .byte 0
alarm_phase:   .byte 0
alarm_hour:    .byte 0
alarm_minute:  .byte 0
alarm_digits:  .space 4, 0
