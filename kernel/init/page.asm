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

.map:
    push rax
    push rcx
    
    mov rcx, qword [rsi + LIMINE_MEMMAP_ENTRY.length]
    shr rcx, STATIC_PAGE_SIZE_shift

    mov rax, KERNEL_PAGE_mirror
    mov rsi, qword [rsi + LIMINE_MEMMAP_ENTRY.base]
    or rax, rsi
    call kernel_page_map

    pop rcx
    pop rax

.next:
    inc rcx
    cmp rcx, qword [rax + LIMINE_MEMMAP_STRUCTURE_RESPONSE.entry_count]
    jne .entry

    mov ecx, STATIC_PAGE_SIZE_page

    mov rax, KERNEL_PAGE_mirror
    mov rsi, qword [r8 + KERNEL_STRUCTURE.lapic_base_address]
    or rax, rsi
    call kernel_page_map

    ; mapping I/O apic controller space
    mov rax, KERNEL_PAGE_mirror
    mov rsi, qword [r8 + KERNEL_STRUCTURE.io_apic_base_address]
    or rax, rsi
    call kernel_page_map

    ; alloc context stack for kernel environment
    mov rax, KERNEL_TASK_STACK_address
    mov ecx, KERNEL_TASK_STACK_SIZE_page
    call kernel_page_alloc

    cmp qword [kernel_limine_kernel_address_request + LIMINE_KERNEL_FILE_ADDRESS_REQUEST.response], EMPTY
    je .error

    cmp qword [kernel_limine_kernel_file_request + LIMINE_KERNEL_FILE_REQUEST.response], EMPTY
    je .error
    
    mov rdx, qword [kernel_limine_kernel_address_requres + LIMINE_KERNEL_FILE_ADDRESS_REQUEST.response]

    ; get pointer to kernel file location response
    mov rdi, qword [kernel_limine_kernel_file_request + LIMINE_KERNEL_FILE_REQUEST.response]
    mov rdi, qword [rdi + LIMINE_KERNEL_FILE_RESPONSE.kernel_file]
    mov rdi, qword [rdi + LIMINE_FILE.address]

    ; number of header in ELF structure
    mov cx, qword [rdi + LIB_ELF_STRUCTURE.header_entry_count]
    
    add rdi, qword [rdi + LIB_ELF_STRUCTURE.header_table_position]

.header:
    cmp byte [rdi + LIB_ELF_STRUCTURE_HEADER.type], EMPTY
    je .leave

    cmp byte [rdi + LIB_ELF_STRUCTURE_HEADER.memory_size], EMPTY
    je .leave

    cmp byte [rdi + LIB_ELF_STRUCTURE_HEADER.memory_size], EMPTY
    je .leave

    push rcx

    ; segment length
    mov rcx, qword [rdi + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    add rcx, qword [rdi + LIB_ELF_STRUCTURE_HEADER.memory_size]
    add rcx, ~STATIC_PAGE_mask
    and cx, STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift
    movzx rcx, cx

    ; segment offset
    mov rsi, ~KERNEL_BASE_address
    and rsi, qword [rdi + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    and si, STATIC_PAGE_mask

    ; kernel segment target
    mov rax, KERNEL_BASE_address
    add rax, rsi
    
    ; kernel segment source
    add rsi, qword byte [rdi + LIB_ELF_STRUCTURE_HEADER.memory_size]
    
    ; map segment to kernel paging array
    call kernel_page_map

    pop rcx

.leave:
    add rdi, LIB_ELF_STRUCTURE_HEADER.SIZE

    ; some entries left
    dec cx
    jns .header

.end:
    mov rax, KERNEL_PAGE_mirror
    or qword [r8 + KERNEL_STRUCTURE.io_apic_base_address], rax
    or qword [r8 + KERNEL_STRUCTURE.lapic_base_address], rax
    or qword [r8 + KERNEL_STRUCTURE.memory_base_address], rax
    or qword [r8 + KERNEL_STRUCTURE.page_base_address], rax

    ; and kernel environment variables
    or qword [kernel_environment_base_address], rax
    or r8, rax
    or r9, rax

    pop r11
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret

.error:
    ; kernel file is not available
    mov rsi, kernel_log_kernel
    call driver_serial_string
    
    jmp $