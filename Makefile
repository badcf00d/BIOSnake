NASM = nasm
NASMFLAGS = -f bin
STANDALONE_FLAGS = -Dfill_sector

SRC_DIR = .
SRC = $(wildcard $(SRC_DIR)/*.asm)

IMG_DIR = .
IMG = $(SRC:.asm=.img)

GAME_FILE = snake.img

.PHONY: clean qemu all standalone

all: $(IMG)
	$(info Done)

standalone: NASMFLAGS += $(STANDALONE_FLAGS)
standalone: $(IMG)

clean:
	rm -f $(IMG)

qemu:
	qemu-system-x86_64 -drive file=$(GAME_FILE),format=raw


%.img: %.asm
	$(NASM) $(NASMFLAGS) -o $@ $<
