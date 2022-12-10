kernel_init_page:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r11

    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write

    ; assign page for PML4 array and get store
    call kernel_memory_alloc_page
    mov qword [r8 + KERNEL_STRUCTURE.page_base_address], rdi
    
    ; all paging procedures use R11 register for PML4 address
    mov r11, rdi

    xor ecx, ecx
    mov rax, qword [kernel_limine_memmap_request + LIMINE_MEMMAP_REQUEST.response]
    mov rdi, qword [rax + LIMINE_MEMMAP_RESPONSE.entry]

.entry:
    mov rsi, qword [rdi + rcx * STATIC_PTR_SIZE_byte]

    cmp qword [rsi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_USABLE
    je .map

    cmp qword [rsi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_KERNEL_AND_MODULES
    je .map

    cmp qword [rsi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_BOOTLOADER_RECLAIMABLE
    je .map
    
    cmp qword [rsi + LIMINE_MEMMAP_ENTRY.type], LIMINE_MEMMAP_FRAMEBUFFER
    jne .next