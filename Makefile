SRC := my_printf.asm
BUILD_DIR := build
TARGET := my_printf

.PHONY: all clean

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(BUILD_DIR)/$(TARGET).o
	ld -g -o $@ $^

$(BUILD_DIR)/$(TARGET).o: $(SRC) | $(BUILD_DIR)
	nasm -f elf64 -g -F dwarf -l $(BUILD_DIR)/$(TARGET).lst -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
