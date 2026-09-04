# TAREA 1:    Reloj/Cronómetro con Alarma Booteable

Proyecto incremental en ensamblador x86 para **Legacy BIOS**. Cada incremento
se mantiene ejecutable para poder probarlo antes de agregar la siguiente
funcionalidad.

## Modo 1 — Bootloader y reloj RTC

- bootloader de 512 bytes con firma `55 AA`;
- bienvenida y carga de una segunda etapa;
- confirmación `S/N` antes de iniciar;
- interfaz de texto mediante `INT 10h`;
- teclado mediante `INT 16h`;
- reloj `HH:MM:SS` obtenido con `INT 1Ah, AH=02h`;
- actualización únicamente cuando cambia el segundo;
- finalización con la tecla `Q`.

## Modo 2 — Cronómetro independiente

- `M` alterna entre el reloj RTC y el cronómetro;
- `S` inicia, pausa y reanuda el conteo;
- `R` reinicia el cronómetro en cualquier momento;
- el tiempo acumulado se conserva mientras está pausado;
- el cronómetro utiliza los ticks BIOS de `INT 1Ah, AH=00h` y no modifica la
  hora del RTC;
- el cambio de medianoche se maneja sin perder el tiempo acumulado;
- la interfaz indica `EN MARCHA` o `PAUSADO`.

## Archivos

| Archivo | Responsabilidad |
|---|---|
| `boot.S` | Sector de arranque y carga de la aplicación. |
| `app_main.S` | Confirmación y ciclo principal del reloj. |
| `bios.S` | Servicios BIOS de video, teclado y RTC. |
| `ui.S` | Pantallas y formato de la hora. |
| `boot.ld`, `app.ld` | Generación de los binarios planos. |
| `Makefile` | Compilación, validación, QEMU y grabación en USB. |

## Compilar

En Ubuntu:

```bash
sudo apt update
sudo apt install build-essential binutils qemu-system-x86
make
make run
```

`make` genera `build/reloj.img` y verifica que:

- `boot.bin` mida exactamente 512 bytes;
- los últimos bytes sean `55 AA`;
- la aplicación quepa en los 16 sectores reservados;
- la imagen tenga el tamaño correcto.

## Pruebas

1. `make` debe terminar con `OK: imagen booteable validada`.
2. `make run` debe mostrar la bienvenida del bootloader.
3. `N` debe finalizar desde la confirmación.
4. `S` debe abrir el modo reloj.
5. La hora debe coincidir con el RTC y avanzar cada segundo.
6. `Q` debe mostrar la despedida y detener la aplicación.
7. `M` debe alternar entre `MODO 1: RELOJ` y `MODO 2: CRONOMETRO`.
8. En el Modo 2, `S` debe iniciar el cronómetro desde `00:00:00`.
9. Una segunda pulsación de `S` debe pausar el valor mostrado.
10. Al pulsar `S` otra vez, el conteo debe continuar desde el valor pausado.
11. `R` debe reiniciarlo a `00:00:00`, tanto pausado como en marcha.
12. Al regresar al Modo 1 con `M`, el reloj RTC debe continuar correctamente.
