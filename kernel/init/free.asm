kernel_init_free:
    ; memory mapping response structure
    mov rsi, qword [kernel_limine_memmap_request + LIMINE_MEMMAP_REQUEST.response]

    ; first entry of memory map
    xor ebx, ebx
    mov rdx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry]

    mov rbp, rsp

.next:
    mov rdi, qword [rdx + rbx * STATIC_PTR_SIZE_byte]
    
    cmp qword [rdi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_BOOTLOEADER_RECLAIMABLE
    jne .omit

    ; save address position and length
    push qword [rdi + LIMINE_MEMMAP_ENTRY.base]
    push qword [rdi + LIMINE_MEMMAP_ENTRY.length]

.omit:
    inc rbx
    
    cmp rbx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry_count]
    jne .next

    ; freed the pages
    xor eax, eax

.area:
    cmp rsp, rbp
    je .end
    
    pop rcx
    shr rcx, STATIC_PAGE_SIZE_shift

    mov rdi, KERNEL_PAGE_mirror
    or rdi, qword [rsp]

    call kernel_page_clean_few

.lock:
    ; request sudo access
    mov dl, lock
    lock xchg byte [r8 + KERNEL_STRUCTURE.memory_semaphore], dl
    
    test dl, dl
    jnz .lock

    ; extend binary memory map
    add qword [r8 + KERNEL_STRUCTURE.page_total], rcx
    add qword [r8 + KERNEL_STRUCTURE.page_available], rcx

    add rax, rcx

    pop rdx
    shr rdx, STATIC_PAGE_SIZE_shift

.register:
    bts qword [r9], rdx
    
    ; next page
    inc rdx

    ; entire space is registered
    dec rcx
    jnz .register

    ; make access
    mov byte [r8 + KERNEL_STRUCTURE.memory_semaphore], UNLOCK
    
    jmp .area

.end:
    mov rsi, kernel_log_prefix
    call driver_serial_string

    shl rax, STATIC_MULTIPLE_BY_4_shift

    mov ebx, STATIC_NUMBER_SYSTEM_decimal
    mov rsi, kernel_log_free
    call driver_serial_value
    call driver_serial_string

    ; reload bsp processor
    jmp kernel_init_ap