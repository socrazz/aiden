kernel_init_free:
    ; memory map response structure
    mov rsi, qword [kernel_limine_memmap_request + LIMINE_MEMMAP_REQUEST.response]

    ; first entry of memory map
    xor ebx, ebx
    mov rdx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry]

    ; array for areas properties
    mov rbp, rsp

.next:
    ; retrieve entry address
    mov rdi, qword [rdx + rbx * STATIC_PTR_SIZE_byte]
    
    ; type of LIMINE_MEMMAP_BOOTLOADER_RECLAIMABLE
    cmp qord [rdi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_BOOTLOADER_RECLAIMABLE
    jne .omit

    ; remember area position and length
    push qword [rdi + LIMINE_MEMMAP_ENTRY.base]
    push qword [rdi + LIMINE_MEMMAP_ENTRY.length]

.omit:
    ; next entry
    inc rbx

    cmp rbx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry_count]
    jne .next

    ; amount of freed up pages
    xor eax, eax

.area:
    cmp rsp, rbp
    je .end

    ; area size in pages
    pop rcx
    shr rcx, STATIC_PAGE_SIZE_shift

    ; area position
    mov rdi, qword [rsp]
    or rdi, qword [kernel_page_mirror]

    ; clean up
    call kernel_page_clean_few

.lock:
    ; request an exclusive access
    mov dl, LOCK
    lock xchg byte [r8 + KERNEL_STRUCTURE.memory_semaphore], dl

    test dl, dl
    jnz .lock

    ; extend binary memory map of those area pages
    add qword [r8 + KERNEL_STRUCTURE.page_total], rcx
    add qword [r8 + KERNEL_STRUCTURE.page_available], rcx

    ; amount of freed up pages
    add rax, rcx

    ; first page of number area
    pop rdx
    shr rdx, STATIC_PAGE_SIZE_shift

.register:
    ; register inside binary memory map
    bts qword [r9], rdx

    ; next page
    inc rdx

    dec rcx
    jnz .register

    ; release access
    mov byte [r8 + KERNEL_STRUCTURE.memory_semaphore], UNLOCK
    
    jmp .area

.end:
    ; prefix
    mov rsi, kernel_log_prefix
    call driver_serial_string

    ; convert pages to KiB
    shl rax, STATIC_MULTIPLE_BY_4_shift

    ; show amount of released memory
    mov ebx, STATIC_NUMBER_SYSTEM_decimal
    mov rsi, kernel_log_free
    call driver_serial_value
    call driver_serial_string

    ; reload bsp processor
    jmp kernel_init_ap