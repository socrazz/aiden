kernel_memory_alloc:
    push rax
    push r8
    push r9

    mov r8, qword [kernel_environment_base_address]

.lock:
    ; request sudo access
    mov al, LOCK
    lock xchg byte [r8 + KERNEL_STRUCTURE.memory_semaphore], al
    
    test al, al
    jnz .lock

    ; start searching from first page of binary memory map
    mov r9, qword [r8 + KERNEL_STRUCTURE.memory_base_address]
    call kernel_memory_acquire
    jc .end

    ; convert page number to its logical address
    shl rdi, STATIC_PAGE_SIZE_shift
    add rdi, qword [kernel_page_mirror]

.end:
    ; release access
    mov byte [r8 + KERNEL_STRUCTURE.memory_semaphore], UNLOCK

    ; restore to original register
    pop r9
    pop r8
    pop rax

    ret

kernel_memory_alloc_page:
    push rcx

    ; alloc only 1 page
    mov ecx, STATIC_PAGE_SIZE_page
    call kernel_memory_alloc
    jc .error

    ; convert page address to physical area
    mov rcx, ~KERNEL_PAGE_mirror
    and rdi, rcx

.error:
    ; restore to original register
    pop rcx
    
    ; return from routine
    ret

kernel_memory_aquire:
    push rax
    push r8
    push rcx

    ; kernel environment variables / routine base addre
    mov r8, qword [kernel_environment_base_address]

    xor eax, eax

.new:
    ; start of considered
    mov rdi, rax
    
    xor ecx, ecx

.check:
    bt qword [r9], rax
    
    ; next page from area and current its length
    inc rax
    inc rcx

    jnc .new

    cmp rcx, qword [rsp]
    je .found

    cmp rax, qword [r8 + KERNEL_STRUCTURE.page_limit]
    je .error

    jmp .check

.found:
    mov rax, rdi


.mark:
    btr qword [r9], rax

    inc rax
    dec rcx
    jnz .mark

    ; allocated successful
    clc
    jmp .end
    
.error:
    stc

.end:
    pop rcx
    pop r8
    pop rax

    ret

kernel_memory_release:
    push rax
    push rcx
    push rdi

    call kernel_page_clean_few
    
    ; convert page
    mov rax, ~KERNEL_PAGE_mirror
    and rax, rdi
    shr rax, STATIC_PAGE_SIZE_shift

    ; put page back to binary memory map
    mov rdi, qword [kernel_environment_base_address]
    mov rdi, qword [rdi + KERNEL_STRUCTURE.memory_base_address]

.page:
    ; release first page of space
    bts qword [rdi], rax

    inc rax
    dec rcx
    jnz .page

    ; restore original registers
    pop rdi
    pop rcx
    pop rax

    ; return from routine
    ret

kernel_memory_release_page:
    push rax
    push rdi

    ; clean page on stack
    call kernel_page_clean

    ; convert page address
    mov rax, ~KERNEL_PAGE_mirror
    and rax, rdi
    shr rax, STATIC_PAGE_SIZE_shift

    ; put page back to binary memory map
    mov rdi, qword [kernel_environment_base_address]
    mov rdi, qword [rdi + KERNEL_STRUCTURE.memory_base_address]
    bts qword [rdi], rax

    pop rdi
    pop rax

    ret

kernel_memory_share:
    push rbx
    push rsi
    push rdi
    push r8
    push r9

    ; kernel environment variabel / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; retrieve pointer to current task descriptor
    call kernel_task_current

    ; reserver space in binary memory map process
    mov r9, qword [r9 + KERNEL_TASK_STRUCTURE.memory_map]
    call kernel_memory_acquire
    jc .end

    ; convert page number to logical address
    shl rdi, STATIC_PAGE_SIZE_shift

    ; map source space to process paging array
    mov rax, rdi
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write | KERNEL_PAGE_FLAG_user | KERNEL_PAGE_FLAG_shared
    sub rsi, qword [kernel_page_mirror]
    call kernel_page_map

.end:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbx

    ret