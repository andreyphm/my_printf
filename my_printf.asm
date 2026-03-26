section .text

global _start                       ; predefined entry points names
global my_printf

_start:         call main

                mov rax, 0x3c             ; exit64 (rdi = error code)
                xor rdi, rdi
                syscall

;---------------------------------------------------------------------------------------------------------------------                
main:           mov rdi, msg
                mov rsi, 'W'
                mov rdx, 'A'
                mov rcx, 'Y'
                mov r8,  'I'
                mov r9,  'S'
                push '?'
                push '?'
                push '?'
                call my_printf

                push rbx
                mov rbx, 5
                cmp rbx, NUM_OF_ARGUMENT_REGS
                pop rbx
                ja .next                        ; if there are no stack arguments then ret 
                sub r10, NUM_OF_ARGUMENT_REGS
                mov rax, r10
                push rbx
                mov rbx, 8
                mul rbx
                pop rdx
                add rsp, rax                    ; go to main return address

.next:          ret

;---------------------------------------------------------------------------------------------------------------------
;Output message to console.
;Arguments: rdi = format string, printf arguments according to calling convention
;Return value: rax = number of symbols in output, r10 = number of specifiers detected
;Destroy: r8
;---------------------------------------------------------------------------------------------------------------------
my_printf:          push rbp
                    push r9
                    push r8
                    push rcx
                    push rdx
                    push rsi                ; for ease of iteration

                    push rbx
                    push r12
                    push r13
                    xor rax, rax
                    xor rbx, rbx
                    xor r12, r12
                    xor r13, r13
                    xor r10, r10
                    mov rbp, rsp

@@cycle:            mov bl, byte [msg + rax]

                    test bl, bl
                    jz @@output             ; if (bl == '\0') break

                    inc rax                 ; symbol counter in input += 1

                    cmp r12b, 1
                    je @@switch             ; specifier flag check

                    cmp bl, '%'
                    je @@percent_found
                    mov byte [output_buffer + r13], bl
                    inc r13                             ; symbol counter in output += 1
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
                            call is_argument_in_register
                            push rbx
                            mov bl, byte [rbp + 8 * NUM_OF_HELPFUL_REGS]
                            mov byte [output_buffer + r13], bl              ; write argument value to output buffer
                            pop rbx
                            add rbp, 8                                      ; go to next argument
                            inc r13
                            inc r10                                         ; increment arguments counter
                            jmp @@cycle

                        case_default:
                            jmp @@cycle

@@output:       mov rdi, 0x01           ; file handle = console output
                mov rsi, output_buffer
                mov rdx, r13            ; rdx = output length

                mov rax, 0x01
                syscall                 ; write64(rdi, rsi, rdx)

                pop r13
                pop r12
                pop rbx
                add rsp, NUM_OF_ARGUMENT_REGS * 8
                pop rbp
                ret

;---------------------------------------------------------------------------------------------------------------------
;Compare r10 with NUM_OF_ARGUMENT_REGS. rbp -= 8 if equal.
;Arguments: r10
;Return value: rbp or rbp -= 8
;Destroy: -
;---------------------------------------------------------------------------------------------------------------------
is_argument_in_register:    cmp r10, NUM_OF_ARGUMENT_REGS
                            jne .exit
                            add rbp, 16

.exit:                      ret                       

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
NUM_OF_HELPFUL_REGS     equ 3
NUM_OF_ARGUMENT_REGS    equ 5

msg:                    db "Andrey %c%c%c %c%c %c%c%c", 0
specifiers_array:       db 'c' 

;---------------------------------------------------------------------------------------------------------------------
section .bss

output_buffer:          resb 4096
