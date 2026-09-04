.code16
.intel_syntax noprefix

.section .text.entry
.global _app_start

.extern bios_clear_screen
.extern bios_wait_key
.extern bios_poll_key
.extern bios_read_rtc
.extern bios_read_ticks
.extern ui_show_confirmation
.extern ui_draw_static
.extern ui_render_dynamic
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
    call compute_stopwatch_display
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
