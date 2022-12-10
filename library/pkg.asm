lib_pkg_file:
    push rcx
    push rsi
    push rdi
    
    ; by default file does not exist
    mov qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.id], EMPTY

.file:
    ; file name length
    cmp qword [rdi + LIB_PKG_STRUCTURE.length], rcx
    jne .next

    add rdi, LIB_PKG_STRUCTURE.name
    call lib_string_compare
    sub rdi, LIB_PKG_STRUCTURE.name

    jnc .found

.next:
    cmp qword [rdi + LIB_PKG_STRUCTURE.offset], EMPTY
    je .end

    ; move pointer to next file
    add rdi, LIB_PKG_base

    jmp .file

.found:
    ; return file specification

    mov ax, qword [rdi + LIB_PKG_STRUCTURE.size]
    mov qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.size_byte], rcx
    
    mov qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.id], rdi

.end:
    pop rdi
    pop rsi
    pop rcx

    ret

lib_pkg_read:
    push rcx
    push rsi
    push rdi

    ; file size in byte
    mov rcx, qword [rsi + LIB_PKG_STRUCTURE.size]

    ; file data position
    add rsi, qword [rsi + LIB_PKG_STRUCTURE.offset]

    ; copy file content
    rep movsb
    
    pop rdi
    pop rsi
    pop rcx

    ret
