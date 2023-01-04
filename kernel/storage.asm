kernel_storage_file:
    push rax
    push rdi
    push r8
    push r10

    ; kernel environment variables / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; by default file does not exist
    mov qwword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.id], EMPTY
    
    ; storage base address
    mov r10, qword [r8 + KERNEL_STRUCTURE.storage_base_address],

    ; check device id overflow
    cmp rax, KERNEL_STORAGE_limit
    jae .end

    ; change device id to offset
    shl rax, KERNEL_STORAGE_STRUCTURE_SIZE_shift

    cmp byte [r10 + rax + KERNEL_STORAGE_STRUCTURE.device_type], KERNEL_STORAGE_TYPE_memory
    jne .end

    ; searching for requested file
    mov rdi, qword [r10 + rax + KERNEL_STORAGE_STRUCTURE.device_first_block]
    call lib_pkg_file

.end:
    pop r10
    pop r8
    pop rdi
    pop rax

    ret

kernel_storage_read:
    push rax
    push r8
    push r10

    ; kernel environment variable / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; storage base address
    mov r10, qword [r8 + KERNEL_STRUCTURE.storage_base_address]

    ; check device id overflow
    cmp rax, KERNEL_STORAGE_limit
    jae .end

    ; chande device id to offset
    shl rax, KERNEL_STORAGE_STRUCTURE_SIZE_shift
    
    cmp byte [r10 + rax + KERNEL_STORAGE_STRUCTURE.device_type], KERNEL_STORAGE_TYPE_memory
    jne .end

    call lib_pkg_read

.end:
    pop r10
    pop r8
    pop rax

    ret

kernel_storage_register:
    push rax
    push rcx
    push r8

    ; kernel environment variable / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; limit device
    mov rcx, KERNEL_STORAGE_limit

    ; base address of device list
    mov rdi, qword [r8 + KERNEL_STRUCTURE.storage_base_address]

.next:
    cmp byte [rdi + KERNEL_STORAGE_STRUCTURE.device_type], EMPTY
    je .register

    ; next slot
    add rdi, KERNEL_STORAGE_STRUCTURE.SIZE
    
    dec rcx
    jnz .next

    xor edi, edi

    jmp .end

.register:
    ; mark slot as used
    lock xchg byte [rdi + KERNEL_STORAGE_STRUCTURE.device_type], al
    jnz .next

.end:
    pop r8
    pop rcx
    pop rax

    ret