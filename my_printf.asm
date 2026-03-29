section .text

%include "macros.inc"

global _start                       ; predefined entry points names
global my_printf

_start:         call main

                mov rax, 0x3c             ; exit64 (rdi = error code)
                xor rdi, rdi
                syscall

;---------------------------------------------------------------------------------------------------------------------                
main:           mov rdi, msg
                mov rsi, -20
                call my_printf

.next:          ret

;---------------------------------------------------------------------------------------------------------------------
; Output message to console.
;
; Arguments: 
;   rdi = format string
;   printf arguments according to AMD calling convention (rsi, rdx, rcx, r8, r9, stack)
;
; Return value: 
;   rax = number of symbols in output
;   r10 = number of processed arguments
;
; Destroy: 
;   r11
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
                    mov r11, rbp

@@cycle:            mov bl, byte [rdi + rax]

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
.next:                  inc r8
                        cmp r8, SPECIFIERS_ARRAY_LEN
                        jae @@cycle                     ; if it's not valid specifier then come back to format string parse cycle
                        jmp @@search_specifier

                        case_c: 
                            call go_to_stack_args
                            mov r8b, byte [r11 + FIRST_SAVED_ARG_OFFSET]
                            mov byte [output_buffer + r13], r8b             ; write argument value to output buffer
                            add r11, 8                                      ; go to next argument
                            inc r13
                            inc r10                                         ; increment arguments counter
                            jmp @@cycle

                        case_s:
                            call go_to_stack_args
                            push rax
                            push rsi
                            mov rsi, qword [r11 + FIRST_SAVED_ARG_OFFSET]
                            .copy_string:   mov al, [rsi]
                                            test al, al
                                            jz .stop_copy
                                            mov [output_buffer + r13], al
                                            inc rsi
                                            inc r13
                                            jmp .copy_string
                                            .stop_copy:     pop rsi
                                                            add r11, 8
                                                            inc r10
                                                            pop rax
                                                            jmp @@cycle

                        case_x:
                            CASE_UNSIGNED 16, hex_digits

                        case_b:
                            CASE_UNSIGNED 2, bin_digits

                        case_o:
                            CASE_UNSIGNED 8, oct_digits

                        case_d:
                            call go_to_stack_args
                            push rax
                            push rdi
                            push rsi
                            push rcx
                            push rbx
                            push rdx

                            mov rdi, qword [r11 + FIRST_SAVED_ARG_OFFSET]
                            test rdi, rdi
                            jns .positive                           ; if rdi >= 0 then jmp
                            mov byte [output_buffer + r13], '-'
                            inc r13
                            neg rdi

                .positive:  mov rbx, 10
                            mov rdx, dec_digits
                            mov rsi, output_buffer
                            add rsi, r13
                            call uint_to_buffer
                            add r13, rax

                            pop rdx
                            pop rbx
                            pop rcx
                            pop rsi
                            pop rdi
                            pop rax
                            add r11, 8
                            inc r10
                            jmp @@cycle

                        case_default:
                            jmp @@cycle

@@output:       mov rdi, 0x01           ; file handle = console output
                mov rsi, output_buffer
                mov rdx, r13            ; rdx = output length

                mov rax, 0x01           ; write64(rdi, rsi, rdx)
                syscall
                mov rax, r13            ; save number of output symbols

                pop r13
                pop r12
                pop rbx
                pop rsi
                pop rdx
                pop rcx
                pop r8
                pop r9
                pop rbp
                ret

;---------------------------------------------------------------------------------------------------------------------
; Jumps over my_printf return address if current number of arguments == NUM_OF_SAVED_ARG_REGS
;
; Arguments: 
;   r10 = current number of arguments
;
; Return value:
;   if (r10 == NUM_OF_SAVED_ARG_REGS) r11 += 16
;
; Destroy: -
;---------------------------------------------------------------------------------------------------------------------
go_to_stack_args:   cmp r10, NUM_OF_SAVED_ARG_REGS
                    jne .exit
                    add r11, 16
.exit:              ret

;---------------------------------------------------------------------------------------------------------------------
; Converts unsigned 64-bit number to string in arbitrary base.
; First writes digits to temporary stack buffer in reverse order,
; then copies them to destination buffer in direct order.
;
; Arguments:
;   rdi = unsigned 64-bit number
;   rsi = destination buffer pointer
;   rbx = base
;   rdx = digits table pointer
;
; Return value:
;   rax = number of copied symbols
;
; Destroy:
;   rcx, r8, rdx, rsi
;---------------------------------------------------------------------------------------------------------------------
uint_to_buffer:     push r12
                    push r13

                    mov r12, rsi            ; r12 = destination buffer
                    mov r13, rdx            ; r13 = digits table pointer
                    sub rsp, 64             ; enough for binary 64-bit representation (the maximum that will be required)
                    lea rsi, [rsp + 63]     ; rsi = pointer to end of temp buffer
                    mov rax, rdi
                    xor rcx, rcx            ; digit counter

                    test rax, rax
                    jnz .convert
                    mov byte [rsi], '0'
                    mov rcx, 1
                    jmp .prepare_copy       ; process zero as a specific input

.convert:           xor rdx, rdx
                    div rbx                 ; rax /= rbx, rdx = rax % rbx
                    mov r8b, [r13 + rdx]
                    mov [rsi], r8b
                    dec rsi
                    inc rcx
                    test rax, rax
                    jnz .convert
                    inc rsi

.prepare_copy:      mov rax, rcx            ; return value = length of number

.copy:              mov r8b, [rsi]
                    mov [r12], r8b
                    inc rsi
                    inc r12
                    dec rcx
                    jnz .copy

                    add rsp, 64             ; restore rsp
                    pop r13
                    pop r12
                    ret

;---------------------------------------------------------------------------------------------------------------------
section .rodata
align 8

specifier:
    dq case_c               ; zero   option: %c
    dq case_s               ; first  option: %s
    dq case_x               ; second option: %x
    dq case_b               ; third  option: %b
    dq case_o               ; fourth option: %o
    dq case_d               ; fifth  option: %d
    dq case_default         ; last   option: come back to @@cycle

;---------------------------------------------------------------------------------------------------------------------
section .data

OUTPUT_BUFFER_SIZE      equ 256
SPECIFIERS_ARRAY_LEN    equ 6
FIRST_SAVED_ARG_OFFSET  equ 24
NUM_OF_SAVED_ARG_REGS   equ 5

msg:                    db "%d", 0
string:                 db "Sickfault", 0
specifiers_array:       db 'c', 's', 'x', 'b', 'o', 'd'
hex_digits:             db "0123456789abcdef"
bin_digits:             db "01"
oct_digits:             db "01234567"
dec_digits:             db "0123456789"

;---------------------------------------------------------------------------------------------------------------------
section .bss

output_buffer:          resb OUTPUT_BUFFER_SIZE
