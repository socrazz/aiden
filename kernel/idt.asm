align 0x80, db 0x00
kernel_irq:
    cmp rax, (kernel_service_list_end - kernel_service_list) / STATIC_QWORD_SIZE_byte
    jnb .return

    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    pushf

    ; execute kernel function according to parameter
    ; in rax
    call qword [kernel_service_list + rax * STATIC_QWORD_SIZE_byte]

    popf
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx

.return:
    ; return from interrupt
    iretq

; align routine
align 0x08, db EMPTY
kernel_id_exception_divide_by_zero:
    push 0
    ; exception id
    push 0

    jmp kernel_idt_exception

; align routine
align 0x08, db EMPTY
kernel_idt_exception_debug:
    push 0
    ; exception id
    push 1

    ; continue
    jmp kernel_idt_exception

; align routine
align 0x08, db EMPTY
kernel_idt_exception_breakpoint:
    push 0
    ; exception id
    push 3

    jmp kernel_idt_exception


align 0x08, db EMPTY
kernel_idt_exception_overflow:
    push 0
    ; execption id
    push 4

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_invalid_opcode:
    push 0
    ; exception id
    push 6

    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_device_not_available:
    push 0
    ; exception id
    push 7
    
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_double_fault:
    ; set exception id
    push 8

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernmel_idt_exception_copreocessor_segment_overrun:
    push 0
    ; exception id
    push 9

    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_invalid_tss:
    ; set exception id
    push 10
    
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_segment_not_present:
    push 11
    
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_stack_segment_fault:
    ; set exception id
    push 12

    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_general_protection_fault:
    ; set exception id
    push 13

    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_page_fault:
    push r14

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_id_exception_x87_floating_point:
    push 0

    ; exception id
    push 16
    
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_alignment_check:
    push 17

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_machine_check:
    push 0
    ; exception id
    push 18

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_simd_floating_point:
    push 0
    ; exception id
    push 19

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_virtualization:
    push 0
    ; exception id
    push 20

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_control_protection:
    ; exception id
    push 21

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_hypervisor_injection:
    push 0
    ; exception id
    push 28

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_vmm_communication:
    ; exception id
    push 29

    ; continue
    jmp kernel_idt_exception

align 0x08, db EMPTY
kernel_idt_exception_security:
    ; exception id
    push 30

kernel_idt_exception:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; put on the stack value of CR2 register
    mov rax, CR2
    push rax

    ; turn off direction flag
    cld

    ; ho on debug conole, exception name
    mov rsi, qword [rsp + KERNEL_IDT_STRUCTURE_EXCEPTION.id]
    ; offset of entry at exception string table
    shl rsi, STATIC_MULTIPLE_BY_PTR_shift
    ; pointer to exception string table entry
    add rsi, kernel_idt_exception_string
    ; pointer to exception description
    mov rsi, qword [rsi]
    call driver_serial_string

    mov rax, qword [rsp + KERNEL_IDT_STRUCTURE_EXCEPTION.rip]
    mov ebx, STATIC_NUMBER_SYSTEM_hexadecimal
    call driver_serial_value

    jmp $

    ; release value of CR2 register from stack
    add rsp, 0x08

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax


    ; release value of exception ID and error code from stack
    add rsp, 0x10

    iretq

align 0x08, db EMPTY
kernel_idt_spurious_interrupt:
    ; return from interrupt
    iretq