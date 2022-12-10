kernel_init_storage:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r11

    cmp qword [kernel_limine_module_request + LIMINE_MODULE_REQUEST.response], EMPTY
    je .error

    mov ecx, ((KERNEL_STORAGE_limit * KERNEL_STORAGE_STRUCTURE.SIZE) + ~STATIC_PAGE_mask) >> STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc

    mov qword [r8 + KERNEL_STRUCTURE.storage_base_address], rdi

    ; save pointer to storage list
    mov qword [r8 + KERNEL_STRUCTURE.storage_base_address], rdi
    
    ; pointer of modules response structure
    mov rbx, qword [kernel_limine_module_request + LIMINE_MODULE_REQUEST.response]

    ; first entry of module list
    xor eax, eax
    mov rdx, qword [rbx + LIMINE_MODULE_RESPONSE.modules]

.next:
    mov r11, qword [rdx + rax * STATIC_PTR_SIZE_byte]

    ; properties of module
    mov rcx, qword [r11 + LIMINE_FILE.size]
    mov rsi, qword [r11 + LIMINE_FILE.address]

    cmp qword [rsi + rcx - LIB_PKG_length], LIB_PKG_magic
    jne .no_pkg

    ; register module as memory storage
    mov al, KERNEL_STORAGE_TYPE_memory
    call kernel_storage_register

    test rdi, rdi
    jz .no_pkg

    ; set device properties
    mov qword [rdi + KERNEL_STORAGE_STRUCTURE.device_blocks], rcx
    mov qword [rdi + KERNEL_STORAGE_STRUCTURE.device_first_block], rsi
    mov qword [rdi + KERNEL_STORAGE_STRUCTURE.storage_file], kernel_storage_file
    mov qword [rdi + KERNEL_STORAGE_STRUCTURE.storage_read], kernel_page_read

.no_pkg:
    inc rax
    cmp rax, qword [rbx + LIMINE_MODULE_RESPONSE.module_count]
    jb .next
    
    mov rcx, KERNEL_STORAGE_limit
    
    mov rax, qword [r8 + KERNEL_STRUCTURE.storage_base_address]

.storage:
    dec rcx
    js .error
    
    cmp byte [rax + KERNEL_STORAGE_STRUCTURE.device_type], EMPTY
    jne .files

    add rax, KERNEL_STORAGE_STRUCTURE.SIZE

    jmp .storage

.files:
    push rax
    push rcx
    
    ; local structure file descriptor
    sub rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE
    mov rbp, rsp

    sub rax, qword [r8 + KERNEL_STRUCTURE.storage_base_address]
    shr rax, KERNEL_STORAGE_STRUCTURE_SIZE_shift

    ; search for init file on storage device
    mov ecx, KERNEL_EXEC_FILE_INIT_length
    mov rsi, kernel_exec_file_init
    call kernel_storage_file

    cmp qword [rsp + KERNEL_STORAG_STRUCTURE_FILE.id], EMPTY
    jne .release

    pop rcx
    pop rax

    jmp .storage

.release:
    ; remove file descriptor from stack
    add rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE
    
    ; restore preserved register
    pop rcx
    pop rax

    ; show information about system storage
    mov rsi, kernel_log_system
    call driver_serial_string

    ; convert Bytes to KiB
    mov rax, qword [rax + KERNEL_STORAGE_STRUCTURE.device_blocks]
    shr rax, STATIC_DIVIDE_BY_4096_shift

    ; show size of system storage
    mov ebx, STATIC_NUMBER_SYSTEM_decimal
    call driver_serial_value

.end:
    pop r11
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

.error:
    mov rsi, kernel_log_storage
    call driver_serial_string

    jmp $