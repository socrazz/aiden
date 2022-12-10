kernel_init_memory:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    cmp qword [kernel_limine_memmap_request + LIMINE_MEMMAP_REQUEST.response],	EMPTY
    je .error

    ; force consistency of available memory space for use
    xor eax, eax

    mov rsi, qword [kernel_limine_memmap_request + LIMINE_MEMMAP_REQUEST.response]
    
    xor ebx, ebx
    mov rdx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry]

.next:
    mov rdi, qword [rdx + rbx * STATIC_PTR_SIZE_byte]

    cmp qword [rdi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_USABLE
    jne .omit

    cmp qword [rdi + LIMINE_MEMMAP_ENTRY.length], rax
    jng .clean_up

    mov rax, qword [rdi + LIMINE_MEMMAP_ENTRY.base]
    mov qword [kernel_environment_base_kernel], rax

    mov rax, qword [rdi + LIMINE_MEMMAP_ENTRY.length]

.clean_up:
    mov rcx, qword [rdi + LIMINE_MEMMAP_ENTRY.LENGTH]
    shr rcx, STATIC_PAGE_SIZE_shift

    mov rdi, qword [rdi + LIMIN_MEMMAP_ENTRY.base]
    call kernel_page_clean_few

.omit:
    inc rbx
    
    cmp rbx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry_count]
    jne .next

    mov r8, qword [kernel_environment_base_address]

    mov r9, KERNEL_STRUCTURE.SIZE
    add r9, ~STATIC_PAGE_mask
    and r9, STATIC_PAGE_mask
    add r9, r8

    mov qword [r8 + KERNEL_STRUCTURE.memory_base_address], r9

    ; memory map response structure
    mov rsi, qword [kernel_limine_memmap_request + LIMINE_MEMMAP_REQUEST.response]
    
    ; first entry of memory map
    xor ebx, ebx
    mov rdx, qword [rsi + KERNEL_MEMMAP_RESPONSE.entry]

.usable:
    ; retrieve entry address
    mov rdi, qword [rdx + rbx * STATIC_PTR_SIZE_byte]
    
    cmp qword [rdi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_USABLE
    jne .leave

    mov rcx, qword [rdi + LIMINE_MEMMAP_ENTRY.length]
    shr rcx, STATIC_PAGE_SIZE_shift
    add qword [r8 + KERNEL_STRUCTURE.page_total], rcx
    add qword [r8 + KERNEL_STRUCTURE.page_available], rcx

    mov rax, qword [rdi + LIMINE_MEMMAP_ENTRY.base]
    add rax, qword [rdi + LIMINE_MEMMAP_ENTRY.length]
    mov qword [r8 + KERNEL_STRUCTURE.page_limit], rax

    mov rax, qword [rdi + LIMINE_MEMMAP_ENTRY.base]
    shr rax, STATIC_PAGE_SIZE_shift

.register:
    bts qword [r9], rax
    inc rax
    dec rcx
    jnz .register

.leave:
    inc rbx
    
    ; end from entries
    cmp rbx, qword [rsi + LIMINE_MEMMAP_RESPONSE.entry_count]
    jne .usable

    ; convert preserved end address of last entry to binary memory map limit in pages
    shr qword [r8 + KERNEL_STRUCTURE.page_limit], STATIC_PAGE_SIZE_shift

    ; first page to be marked
    mov rbx, r8
    shr rbx, STATIC_PAGE_SIZE_shift

    ; length of binary memory map in bytes
    mov rcx, qword [r8 + KERNEL_STRUCTURE.page_limit]
    shr rcx, STATIC_DIVIDE_BY_8_shift

    ; sum with binary memory map address
    add rcx, r9
    
    ; and substract kernel environment variables/routines
    sub rcx, r8

    ; align length to page boundaries and convert to pages
    add rcx, ~STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift

    sub qword [r8 + KERNEL_STRUCTURE.page_available], rcx

.mark:
    btr qword [r9], rbx
    inc rbx

    dec rcx
    jnz .mark

    ; restore original register
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret

.error:
    mov rsi, kernel_log_memory
    call driver_serial_string
    
    jmp $