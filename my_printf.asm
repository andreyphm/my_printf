section .text

global _start                       ; predefined entry points names for ld
global my_printf

_start:         call main

                mov rax, 0x3c           ; exit64 (rdi = error code)
                xor rdi, rdi
                syscall

;---------------------------------------------------------------------------------------------------------------------                
main:           mov rsi, msg
                mov rdi, 'I'
                call my_printf

                ret

;---------------------------------------------------------------------------------------------------------------------
;Output message with % specifiers to console.
;Arguments: rsi = format string, rdi - printf argument
;Return value: rax = number of symbols in output
;Destroy: r8
;---------------------------------------------------------------------------------------------------------------------
my_printf:          xor rax, rax
                    push rbx
                    xor rbx, rbx
                    push r12
                    push r13
                    xor r13, r13
                    xor r12, r12

@@cycle:            mov bl, byte [msg + rax]

                    test bl, bl
                    jz @@output             ; if (bl == '\0') break

                    add rax, 1              ; symbol counter in input += 1

                    cmp r12b, 1
                    je @@switch             ; specifier flag check

                    cmp bl, '%'
                    je @@percent_found
                    mov byte [output_buffer + r13], bl
                    add r13, 1                          ; symbol counter in output += 1
                    jmp @@cycle

@@percent_found:    mov r12b, 1             ; specifier flag on
                    jmp @@cycle

@@switch:               xor r12b, r12b          ; specifier flag off
                        xor r8, r8

@@search_specifier:     cmp bl, [specifiers_array + r8]
                        jne .next
                        jmp qword [specifier + r8 * 8]            ; jump to specific jump table label
.next:                  add r8, 1
                        cmp r8, SPECIFIERS_ARRAY_LEN
                        jae @@cycle                     ; if it's not valid specifier then come back to str parse cycle
                        jmp @@search_specifier

                        case_c: 
                            mov byte [output_buffer + r13], dil
                            add r13, 1
                            jmp @@cycle

                        case_default:
                            jmp @@cycle

@@output:       mov rax, 0x01
                mov rdi, 0x01           ; file handle = console output
                mov rsi, output_buffer
                mov rdx, r13            ; rdx = output length

                syscall                 ; write64(rdi, rsi, rdx)

                pop r13
                pop r12
                pop rbx
                ret

;---------------------------------------------------------------------------------------------------------------------
;Calculates length of null-terminated string.
;Arguments: rsi = string pointer
;Return value: rax = string length
;Destroy: -
;---------------------------------------------------------------------------------------------------------------------
my_strlen:      push rbx
                xor rax, rax

.cycle:         mov bl, byte [msg + rax]
                add rax, 1
                test bl, bl
                jnz .cycle
                sub rax, 1

                pop rbx
                ret

;---------------------------------------------------------------------------------------------------------------------
section .rodata
align 8

specifier:
    dq case_c               ; zero option: %c
    dq case_default         ; last option: come back to @@cycle

;---------------------------------------------------------------------------------------------------------------------
section .data

SPECIFIERS_ARRAY_LEN    equ 1

msg:                    db "Andrey%c", 0
specifiers_array:       db 'c' 

;---------------------------------------------------------------------------------------------------------------------
section .bss

output_buffer:          resb 4096
