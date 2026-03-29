%macro CASE_UNSIGNED 2
    call go_to_stack_args
    push rax
    push rdi
    push rsi
    push rcx
    push rbx
    push rdx

    mov rbx, %1                                     ; rbx = base
    mov rdx, %2                                     ; rdx = digits table pointer
    mov rdi, qword [r11 + FIRST_SAVED_ARG_OFFSET]
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
    jmp cycle
%endmacro
