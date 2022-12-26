kernel_library_add:
    push rcx
    push r14

    ; search from first entry
    xor ecx, ecx

    ; setting pointer to begining of library entries
    mov r14, qword [kernel_environment_base_address]
    mov r14, qword [r14 + KERNEL_STRUCTURE.library_base_address]

.next:
    ; entry
    test word [r14 + KERNEL_LIBRARY_STRUCTURE.flags], KERNEL_LIBRARY_FLAG_active
    jz .found

    ; move pointer to next entry
    add r14, KERNEL_LIBRARY_STRUCTURE.SIZE
    
    ; end of library structure
    inc rcx
    cmp rcx, KERNEL_LIBRARY_limit
    jb .next

    ; free entry not found
    stc
    
    jmp .end

.found:
    ; mark entry as active
    mov word [r14 + KERNEL_LIBRARY_STRUCTURE.flags], KERNEL_LIBRARY_FLAG_active
    
    ; retry entry pointer
    mov qword [rsp], r14

.end:
    pop r14
    pop rcx

    ret

kernel_library_find:
    push rbx
    push rdi
    push r14

    ; search from first entry
    xor ebx, ebx

    ; set pointer to begining of library entries
    mov r14, qword [kernel_environment_base_address]
    mov r14, qword [r14 + KERNEL_STRUCTURE.library_base_address]

.find:
    cmp word [r14 + KERNEL_LIBRARY_STRUCTURE.flags], EMPTY
    je  .next
    
    ; length of entry name
    cmp byte [r14 + KERNEL_LIBRARY_STRUCTURE.length], cl
    jne .next

    ; check found library
    lea rdi, [r14 + KERNEL_LIBRARY_STRUCTURE.name]
    call lib_string_compare
    jnc .found

.next:
    ; get move pointer to the next entry
    add r14, KERNEL_LIBRARY_STRUCTURE.size
    
    inc ebx
    cmp ebx, KERNEL_LIBRARY_limit
    jb .find
    
    stc
    
    jmp .end

.found:
    ; return the entry pointer
    mov qword [rsp], r14

.end:
    pop r14
    pop rdi
    pop rbx

    ret

kernel_library_import:
    push rcx
    push rsi
    push r14
    push r13

    ; number of entries in section header
    movzx ecx, word [r13 + LIB_ELF_STRUCTURE.section_entry_count]
    
    ; set pointer to begining of section header
    add r13, qword [r13 + LIB_ELF_STRUCTURE.section_table_section]

.section:
    ; check string table
    cmp dword [r13 + LIB_ELF_STRUCTURE_SECTION.type], LIB_ELF_SECTION_TYPE_strtab
    jne .next

    ; preserve pointer to string table
    mov rsi, qword [rsp]
    add rsi, qword [r13 + LIB_STRUCTURE_SECTION.file_offset]

.next:
    ; dynamic section
    cmp word [r13 + LIB_ELF_STRUCTURE_SECTION.type], LIB_SECTION_TYPE_dyanmic
    je .kernel_page_address

    ; move pointer to next entry
    add r13, LIB_ELF_STRUCTURE_SECTION.SIZE

    ; check end library of structure
    add r13, LIB_ELF_STRUCTURE_SECTION.SIZE

    loop .section

.parse:
    ; set pointer to dynamic section
    mov r13, qword [r13 + LIB_ELF_STRUCTURE.file_offset]
    add r13, qword [rsp]

.library:
    cmp qword [r13 + LIB_ELF_STRUCTURE_SECTION_DYNAMIC.type], EMPTY
    je .end

    cmp qword [r13 + LIB_ELF_STRUCTURE_SECTION_DYNAMIC.type], LIB_ELF_SECTION_DYNAMIC_TYPE_needed
    jne .omit

    push rcx
    push rsi

    ; set pointer to library name
    add rsi, qword [r13 + LIB_ELF_STRUCTURE_SECTION_DYNAMIC.offset]

    ; calculate string length
    call lib_string_length

    ; load library
    call kernel_library_load

    pop rsi
    pop rcx

    jc .end

.omit:
    ; next entry from list
    add r13, LIB_ELF_STRUCTURE_SECTION_DYNAMIC.SIZE
    
    ; continue
    jmp .library

.end:
    pop r13
    pop r14
    pop rsi
    pop rcx

    ret

kernel_library_function:
    push	rbx
	push	rcx
	push	rdx
	push	rsi
	push	rdi
	push	r13
	push	r14

    ; searching for first entry
    xor ebx, ebx

    mov r14, qword [kernel_environment_base_address]
    mov r14, qword [r14 + KERNEL_STRUCTURE.library_base_address]

.library:
    cmp ord [r14 + KERNEL_LIBRARY_STRUCTURE.flags], KERNEL_LIBRARY_FLAG_active
    je .library_parse

.library_next:
    ; move pointer to next library
    add r14, KERNEL_LIBRARY_STRUCTURE.SIZE

    inc ebx
    cmp ebx, KERNEL_LIBRARY_limit
    jb .library
    
    stc

    jmp .end


