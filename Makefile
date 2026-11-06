NASM ?= nasm
LD = ld
NASMFLAGS ?=
LDFLAGS ?=

.PHONY: all run test clean

all: perceptron

perceptron: main.o
	$(LD) $(LDFLAGS) -o $@ $<

main.o: main.asm
	$(NASM) -f elf64 -Werror $(NASMFLAGS) -o $@ $<

run: perceptron
	./perceptron

test: perceptron
	NASM="$(NASM)" LD="$(LD)" sh tests/test.sh

clean:
	rm -f main.o perceptron
