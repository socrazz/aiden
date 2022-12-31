kernel_init_library:
    push rcx
    push rdi

    ; asssign space for library list
    mov rcx, ((KERNEL_LIBRARY_limit * KERNEL_LIBRARY_STRUCTURE.SIZE) + ~STATIC_PAGE_mask) >> STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc

    ; savei pointer to library list
    mov qword [r8 + KERNEL_STRUCTURE.library_base_address], rdi

    ; assign space for memroy map of library pace
    call kernel_memory_alloc_page
    or rdi, qword [kernel_page_mirror]

    ; save pointer to library memory map
    mov qword [r8 + KERNEL_STRUCTURE.library_memory_map_addres], rdi

    ; filling memory map with available pages
    mov al, STATIC_MAX_unsigned
    mov rcx, KERNEL_EXEC_BASE_addres
    shr rcx, STATIC_PAGE_SIZE_shift
    shr rcx, STATIC_DIVIDE_BY_8_shift
    rep stosb

    ; restore original register
    pop rdi
    pop rcx

    ; return data from routine
    ret