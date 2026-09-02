# CE 4303 — Reloj/Cronómetro con Alarma Booteable

Proyecto incremental en ensamblador x86 para **Legacy BIOS**. Cada incremento
se mantiene ejecutable para poder probarlo antes de agregar la siguiente
funcionalidad.

## Incremento 1 — Bootloader y reloj RTC

Estado actual:

- bootloader de 512 bytes con firma `55 AA`;
- bienvenida y carga de una segunda etapa;
- confirmación `S/N` antes de iniciar;
- interfaz de texto mediante `INT 10h`;
- teclado mediante `INT 16h`;
- reloj `HH:MM:SS` obtenido con `INT 1Ah, AH=02h`;
- actualización únicamente cuando cambia el segundo;
- finalización con la tecla `Q`.

## Plan de commits

| Commit | Funcionalidad comprobable |
|---|---|
| 1 | Bootloader, confirmación, pantalla y reloj RTC en tiempo real. |
| 2 | Cronómetro independiente: iniciar, pausar, reanudar, reiniciar y cambiar de modo. |
| 3 | Alarma `HH:MM`, aviso visual/sonoro, cancelación, pruebas y documentación final. |

Los commits 2 y 3 se realizarán en días distintos, después de probar el
incremento anterior y aplicar las correcciones necesarias.

## Archivos actuales

| Archivo | Responsabilidad |
|---|---|
| `boot.S` | Sector de arranque y carga de la aplicación. |
| `app_main.S` | Confirmación y ciclo principal del reloj. |
| `bios.S` | Servicios BIOS de video, teclado y RTC. |
| `ui.S` | Pantallas y formato de la hora. |
| `boot.ld`, `app.ld` | Generación de los binarios planos. |
| `Makefile` | Compilación, validación, QEMU y grabación en USB. |

## Compilar

En Debian o Ubuntu:

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

## Pruebas del incremento 1

1. `make` debe terminar con `OK: imagen booteable validada`.
2. `make run` debe mostrar la bienvenida del bootloader.
3. `N` debe finalizar desde la confirmación.
4. `S` debe abrir el modo reloj.
5. La hora debe coincidir con el RTC y avanzar cada segundo.
6. `Q` debe mostrar la despedida y detener la aplicación.

## Hardware real

Antes de grabar, confirme cuidadosamente el dispositivo con `lsblk`. El comando
siguiente sobrescribe el dispositivo completo:

```bash
make install-usb DEVICE=/dev/sdX
```

La prueba en hardware real se realizará después de validar primero la imagen en
QEMU.
