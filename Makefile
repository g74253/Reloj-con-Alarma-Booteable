AS      := as
LD      := ld
ASFLAGS := --32
LDFLAGS := -m elf_i386

BUILD       := build
APP_SECTORS := 16
IMAGE       := $(BUILD)/reloj.img

APP_OBJECTS := $(BUILD)/app_main.o $(BUILD)/bios.o $(BUILD)/ui.o

.PHONY: all clean check run debug install-usb help

all: $(IMAGE) check

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/boot.o: boot.S | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD)/app_main.o: app_main.S | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD)/bios.o: bios.S | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD)/ui.o: ui.S | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD)/boot.bin: $(BUILD)/boot.o boot.ld
	$(LD) $(LDFLAGS) -T boot.ld -o $@ $(BUILD)/boot.o

$(BUILD)/app.bin: $(APP_OBJECTS) app.ld
	$(LD) $(LDFLAGS) -T app.ld -o $@ $(APP_OBJECTS)

$(IMAGE): $(BUILD)/boot.bin $(BUILD)/app.bin
	truncate -s $$(( (1 + $(APP_SECTORS)) * 512 )) $@
	dd if=$(BUILD)/boot.bin of=$@ bs=512 seek=0 conv=notrunc status=none
	dd if=$(BUILD)/app.bin  of=$@ bs=512 seek=1 conv=notrunc status=none

check: $(BUILD)/boot.bin $(BUILD)/app.bin $(IMAGE)
	@test "$$(stat -c%s $(BUILD)/boot.bin)" -eq 512 || \
		(printf 'ERROR: boot.bin no mide 512 bytes\n' && false)
	@test "$$(stat -c%s $(BUILD)/app.bin)" -le $$(( $(APP_SECTORS) * 512 )) || \
		(printf 'ERROR: app.bin excede %s sectores\n' "$(APP_SECTORS)" && false)
	@test "$$(od -An -tx1 -j510 -N2 $(BUILD)/boot.bin | tr -d ' \n')" = "55aa" || \
		(printf 'ERROR: falta la firma 55 AA\n' && false)
	@test "$$(stat -c%s $(IMAGE))" -eq $$(( (1 + $(APP_SECTORS)) * 512 )) || \
		(printf 'ERROR: tamano inesperado de la imagen\n' && false)
	@printf 'OK: imagen booteable validada: %s\n' "$(IMAGE)"

run: all
	qemu-system-i386 -drive format=raw,file=$(IMAGE) -boot c -rtc base=localtime

debug: all
	qemu-system-i386 -drive format=raw,file=$(IMAGE) -boot c -rtc base=localtime \
		-S -s

# Ejemplo seguro: make install-usb DEVICE=/dev/sdX
# ADVERTENCIA: sobrescribe el dispositivo indicado.
install-usb: all
	@test -n "$(DEVICE)" || (printf 'Use: make install-usb DEVICE=/dev/sdX\n' && false)
	@test -b "$(DEVICE)" || (printf 'ERROR: DEVICE no es un dispositivo de bloques\n' && false)
	sudo dd if=$(IMAGE) of=$(DEVICE) bs=4M conv=fsync status=progress

clean:
	rm -rf $(BUILD)

help:
	@printf '%s\n' \
		'make              Compila y valida build/reloj.img' \
		'make run          Ejecuta la imagen en QEMU' \
		'make debug        Espera GDB en localhost:1234' \
		'make install-usb DEVICE=/dev/sdX  Graba en USB (destructivo)' \
		'make clean        Elimina archivos generados'
