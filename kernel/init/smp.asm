kernel_init_smp:
    cmp qword [kernel_limine_smp_request + LIMINE_SMP_REQUEST.response], EMPTY
    je .alone
    
    mov rsi, qword [kernel_limine_smp_request + LIMINE_SMP_REQUEST.response]

    mov rcx, qword [rsi + LIMINE_SMP_RESPONSE.cpu_count]
    mov rsi, qword [rsi + LIMINE_SMP_RESPONSE.cpu_info]

    call kernel_lapic_id

.next:
    dec rcx
    js .alone

    mov rdi, qword [rsi + rcx * STATIC_PTR_SIZE_byte]
    
    cmp dword [rdi + LIMINE_SMP_INFO.lapic_id], eax
    je .next

.alone:
    cmp qword [kernel_smp_count], EMPTY
    
    je .free
    mov rsi, kernel_log_prefix
    call driver_serial_string
    
    mov rax, qword [kernel_smp_count]
    mov ebx, STATIC_NUMBER_SYSTEM_decimal
    mov rsi, kernel_log_smp
    call driver_serial_value
    call driver_serial_string

.free:
    jmp kernel_init_free