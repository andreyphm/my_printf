SRC_ASM := my_printf.asm
SRC_C   := main.c

BUILD_DIR := build
TARGET := my_printf

.PHONY: all clean

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(BUILD_DIR)/my_printf.o $(BUILD_DIR)/main.o
	gcc -g -no-pie -o $@ $^

$(BUILD_DIR)/my_printf.o: $(SRC_ASM) | $(BUILD_DIR)
	nasm -f elf64 -g -F dwarf -l $(BUILD_DIR)/my_printf.lst -o $@ $<

$(BUILD_DIR)/main.o: $(SRC_C) | $(BUILD_DIR)
	gcc -c -g -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
