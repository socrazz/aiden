kernel_init_gdt:
    push rax
    push rcx
    push rdi
    
    ; assign space for gdt and store
    mov ecx, STATIC_PAGE_SIZE_pge
    call kernel_memory_alloc
    mov qword [kernel_gdt_header + KERNEL_GDT_STRUCTURE_HEADER.adddress], rdi

    ; make code descriptor
    mov rax, 0000000000100000100110000000000000000000000000000000000000000000b
    mov qword [rdi + KERNEL_GDT_STRUCTURE.cs_ring0], rax
    
    ; make data descriptor
    mov rax, 0000000000100000100100100000000000000000000000000000000000000000b
    mov qword [rdi + KERNEL_GDT_STRUCTURE.ds_ring0], rax

    mov rax, 0000000000100000111110000000000000000000000000000000000000000000b
    mov qword [rdi + KERNEL_GDT_STRUCTURE.cs_ring3], rax
    
    mov rax, 0000000000100000111100100000000000000000000000000000000000000000b
    mov qword [rdi + KERNEL_GDT_STRUCTURE.ds_ring3], rax

    ; reload global descriptor table
    lgdt [kernel_gdt_header]

    ; set proper descriptor
    call kernel_init_gdt_reload

    pop rdi
    pop rcx
    pop rax

    ret

kernel_init_gdt_reload:
    push rax

    ; reload code descriptor
    push KERNEL_GDT_STRUCTURE.cs_ring0
    push .cs_reload
    retfq

.cs_reload:
    xor ax, ax
    mov fs, ax
    mov gs, ax

    ; reload global selectors kernel
    mov ax, KERNEL_GDT_STRUCTURE.ds_ring0
    ; data
    mov ds, ax
    ; extra
    mov es, ax
    ; stack
    mov ss, ax

    pop rax
    
    ret