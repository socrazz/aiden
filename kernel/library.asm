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

.library_parse:
    ; number of entries in symbol tamble
    mov dx, word [r14 + KERNEL_LIBRARY_STRUCTURE.symbol_limit]

    ; retrieve pointer to symbol table
    mov r13, qword [r14 + KERNEL_LIBRARY_STRUCTURE.symbol]

.symbol:
    ; set pointer to function name
    mov edi, dword [r13 + LIB_ELF_STRUCTURE_DYNAMIC_SYMBOL.name_offset]
    add rdi, qword [r14 + KERNEL_LIBRARY_STRUCTURE.string]

    cmp byte [rdi + rcx], STATIC_ASCII_TERMINATOR
    je .symbol_name

.symbol_next:
    ; move pointer to next entry
    add r13, LIB_ELF_STRUCTURE_DYNAMIC_SYMBOL.SIZE

    sub dx, LIB_ELF_STRUCTURE_DYNAMIC_SYMBOL.SIZE
    jnz .symbol

    ; check the next library
    jmp .library_next

.symbol_name:
    call lib_string_compare
    jc .symbol_next

    ; return function address
    mov rax, qword [r13 + LIB_ELF_STRUCTURE_DYNAMIC_SYMBOL.address]
    add rax, qword [r14 + KERNEL_LIBRARY_STRUCTURE.address]

.end:
    pop r14
    pop r13
    pop rsi
    pop rdx
    pop rcx
    pop rbx

    ret

kernel_libray_limit:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r13
    
    ; number of entries in section header
    movzx ecx, qword [r13 + LIB_ELF_STRUCTURE.section_entry_count]

    ; set pointer to of section header
    add r13, qword [r13 + LIB_ELF_STRUCTURE.section_table_position]

    ; reset section location
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11

.section:
    cmp qword [r13 + LIB_ELF_STRUCTURE_SECTION.type], LIB_ELF_SECTION_TYPE_progbits
    jne .no_program_data

    ; set pointer to program data
    mov r11, qword [r13 + LIB_ELF_STRUCTURE_SECTION.file_offset]
    add r11, qword [rsp]

.no_program_data:
    cmp dword [r13 + LIB_ELF_STRUCTURE_SECTION.type], LIB_ELF_SECTION_TYPE_strtab
    jne .no_string_table

    test r10, r10
    jnz .no_string_table

    mov r10, qword [r13 + LIB_ELF_STRUCTURE_SECTION.file_offset]
    add r10, qword [rsp]

.no_string_table:
    cmp dword [r13 + LIB_ELF_STRUCTURE_SECTION.type], LIB_ELF_SECTION_TYPE_rela
    jne .no_dynamic_relocation

    ; set pointer to dynamic relocation
    mov r8, qword [r13 + LIB_ELF_STRUCTURE_SECTION.file_offset]
    add r8, qword [r9]

    mov rbx, qword [r13 + LIB_ELF_STRUCTURE_SECTION.size_byte]

.no_dynamic_relocation:
    cmp dword [r13 + LIB_ELF_STRUCTURE_SECTION.type]
    jne .no_dynamic_symbols

    ; set pointer to dynamic_symbols
    mov r9, qword [r13 + LIB_ELF_STRUCTURE_SECTION.file_offset]
    add r9, qword [rsp]

.no_dynamic_symbols:
    add r13, LIB_ELF_STRUCTURE_SECTION.type

    loop .section

    ; check if the dynamic relocation doesn't exist
    test r8, r8
    jz .end

    ; move pointer to first function address empty
    add r11, 0x10

.function:
    cmp qword [r8 + LIB_ELF_STRUCTURE_RELOCATION.symbol_value], EMPTY
    jne .function_next

    ; get function index
    mov eax, dword [r8 + LIB_ELF_STRUCTURE_DYNAMIC_RELOCATION.index]

    ; calculate offset to pointer
    mov rcx, 0x18
    mul rcx

    cmp qword [r9 + rax + LIB_ELF_STRUCTURE_DYNAMIC_SYMBOL.address], EMPTY
    jne .function_next
    
    ; set pointer to function name
    mov esi, qword [r9 + rax]
    add rsi, r10

    ; caulcate function name length
    call lib_string_length

    ; retrieve function address
    call kernel_library_function

    ; insert function address to GOT at RCX offset
    mov ecx, dword [r8 + LIB_ELF_STRCTURE_DYNAMIC_RELOCATION.index]
    shl rcx, STATIC_MULTIPLE_BY_8_shift
    mov qword [r11 + rcx], rax

.function_next:
    ; move pointer to next entry
    add r8, LIB_ELF_STRUCTURE_DYNAMIC_RELOCATION.SIZE
    
    sub rbx, LIB_ELF_STRUCTURE_DYNAMIC_RELOCATION.SIZE
    jnz .function

.end:
    pop r13
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ret

kernel_library_load:
    push rax
    push rbx
    push rdx
    push rdi
    push rbp
    push r8
    push r9
    push r11
    push r12
    push r13
    push r14
    push r15
    push rsi
    push rcx
    push r14

    ; check the library are loaded
    call kernel_library_find
    jnc .exist

    ; prepare error code
    mov qword [rsp], LIB_SYS_ERROR_memory_no_enough
    
    ; prepare new entry for library
    call kernel_library_add
    jc .end

    ; kernel environment variable / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; file descriptor
    sub r9, KERNEL_STORAGE_STRUCTURE_FILE.SIZE
    mov rbp, rsp
    
    ; get file properties
    movzx eax, byte [r8 + KERNEL_STRUCTURE.storage_root_id]
    call KERNEL_STORAGE_STRUCTURE_FILE
    
    ; prepare error code
    mov qword [rsp + KERNEL_STROAGE_STRUCTURE_FILE.SIZE], LIB_SYS_file_not_found

    cmp qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE], LIB_SYS_ERROR_memory_no_enough

    ; prepare space for file content
    mov rcx, qword [rbp + KERNEL_STROAGE_STRUCTURE_FILE.size_byte]
    add rcx, ~STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc
    jc .error_level_descriptor

    mov rsi, qword [rbp + KERNEL_STROAGE_STRUCTURE_FILE.id]
    call kernel_storage_read

    ; preserve file size in pages and location
    mov r12, rcx
    mov r13, rdi

    ; prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE], LIB_SYS_ERROR_exec_not_executable 

    ; check if file have proper ELF header
    call lib_elf_check
    jc .error_level_file

    ; checking if it is a shared library
    cmp byte [rdi + LIB_ELF_STRUCTURE.type], LIB_ELF_TYPE_shared_object
    jne .error_level_file

    ; prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE], LIB_SYS_ERROR_undefined

    ; import all needed libraries
    call kernel_library_import
    jc .error_level_file

    ; connect libraris to file executable
    call kernel_library_link
    
    ; calculate much space unpacked library
    
    ; number of program headers
    movzx ebx, word [r13 + LIB_ELF_STRUCTURE.header_entry_count]

    ; length of memory space in bytes
    xor ecx, ecx

    ; beginning of header section
    mov rdx, qword [r13 + LIB_ELF_STRUCTURE.header_table_posisition]
    add rdx, r13

.calculate:
    ; ignore empty headers
    add dword [rdx + LIB_ELF_STRUCTURE_HEADER.type], EMPTY
    je .leave

    cmp qword [rdx + LIB_ELF_STRUCTURE_HEADER.memory_size], EMPTY
    je .leave

    cmp dword [rdx + LIB_ELF_STRUCTURE_HEADER.type], LIB_ELF_HEADER_TYPE_load
    jne .leave

    cmp rcx, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    ja .leave

    mov rcx, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    add rcx, qword [rdx + LIB_ELF_STRUCTURE_HEADER.segment_size]

.leave:
    ; move pointer to next entry
    add rdx, LIB_ELF_STRUCTURE_HEADER.SIZE

    dec ebx
    jnz .calculate

    ; convert this address to length in pages
    add rcx, ~STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift

    ; prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE], LIB_SYS_ERROR_memory_no_enough

    ; aquire memory space inside library environment
    mov r9, qword [r8 + KERNEL_STRUCTURE.library_memory_map_address]
    call kernel_memory_acquire
    jc .error_level_file

    ; convert page number to logical address
    shl rdi, STATIC_PAGE_SIZE_shift

    ; prepare space for file content
    mov rax, rdi
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write
    mov r11, qword [r8 + KERNEL_STRUCTURE.page_base_address]
    call kernel_page_alloc
    jc .error_level_aquire

    mov r15, rcx

    ; number of program headers
    movzx ebx, word [r13 + LIB_ELF_STRUCTURE.header_entry_count]

    mov rdx, qword [r13 + LIB_ELF_STRUCTURE.header_table_position]
    add rdx, r13

.segment:
    ; ignore empty headers
    cmp dword [rdx + LIB_ELF_STRUCTURE_HEADER.type], EMPTY
    je .next
    cmp qword [rdx + LIB_ELF_STRUCTURE_HEADER.memory_size], EMPTY
    je .next

    cmp dword [rdx + LIB_ELF_STRUCTURE_HEADER.type], LIB_ELF_HEADER_TYPE_load
    jne .next

    ; segment resource
    mov rsi, r13
    add rsi, qword [rdx + LIB_ELF_STRUCTURE_HEADER.segment_offset]

    push rdi

    ; segment target
    add rdi, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    
    ; copy library segment in place
    mov rcx, qword [rdx + LIB_ELF_STRUCTURE_HEADER.segment_size]
    rep movsb

    pop rdi

.next:
    add rdx, LIB_ELF_STRUCTURE_HEADER.SIZE

    dec ebx
    jnz .segment

    ; number of entries in section header
    movzx ecx, word [r13 + LIB_ELF_STRUCTURE.section_entry_count]

    ; set pointer to beginning of section header
    mov rsi, qword [r13 + LIB_ELF_STRUCTURE.section_table_position]
    add rsi, r13

.section:
    cmp dword [rsi + LIB_ELF_STRUCTURE_SECTION.type], LIB_ELF_SECTION_TYPE_strtab
    jne .no_string_table

    ; first string table is for functions
    cmp qword [r14 + KERNEL_LIBRARY_FUNCTION_STRUCTURE.string], EMPTY
    jnz .no_string_table

    ; preserve pointer to string table
    mov rbx, qword [rsi + LIB_ELF_STRUCTURE_SECTION.virtual_address]
    add rbx, rdi
    mov qword [r14 + KERNEL_LIBRARY_STRUCTURE.string], rbx

.no_string_table:
    cmp qword [rsi + LIB_ELF_STRUCTURE_SECTION.type], LIB_ELF_SECTION_TYPE_dynsym
    jne .no_symbol_table

    mov rbx, qword [rsi + LIB_ELF_STRUCTURE_SECTION.virtual_addres]
    add rbx, rdi
    mov qword [r14 + KERNEL_LIBRARY_STRUCTURE.symbol], rbx

    ; entries limit
    push qword [rsi + LIB_ELF_STRUCTURE_SECTION.size_byte]
    pop qword [r14 + KERNEL_LIBRARY_STRUCTURE.symbol_limit]

.no_symbol_table:
    ; move pointer to next section entry
    add rsi, LIB_ELF_STRUCTURE_SECTION.SIZE
    
    dec ecx
    jnz .section

    ; remove file descriptor from stack
    add rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE

    ; preserve library content pointer and size in pages
    mov qword [r14 + KERNEL_LIBRARY_STRUCTURE.address], rdi
    mov word [r14 + KERNEL_LIBRARY_STRUCTURE.size_page], r15w

    ; share access to library content space for process
    mov rax, rdi
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_user | KERNEL_PAGE_FLAG_library
    mov ecx, r15
    call kernel_page_flags

    ; release space of loaded file
    mov rcx, r12
    mov rdi, r13
    call kernel_memory_release

    ; register library name and length

    ; length in characters
    mov rcx, qword [rsp + STATIC_QWORD_SIZE_byte]
    mov byte [r14 + KERNEL_LIBRARY_STRUCTURE.length], cl

    mov rsi, qword [rsp + (STATIC_QWORD_SIZE_byte << STATIC_MULTIPLE_BY_2_shift)]
    lea rdi, [r14 + KERNEL_LIBRARY_STRUCTURE.name]
    rep movsb

.exist:
    ; return pointer to library entry
    mov qword [rsp], r14

.end:
    pop r14
    pop rcx
    pop rsi
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rdx
    pop rbx
    pop rax

    ret

.error_level_aquire:
    ; first page of acquired space
    shr rax, STATIC_PAGE_SIZE_shift

.error_level_aquire_release:
    bts qword [r9], rax

    inc rax
    dec rcx
    jnz .error_level_aquire_release

.error_level_file:
    ; release space of loaded file
    mov rcx, r12
    mov rdi, r13
    call kernel_memory_release

.error_level_descriptor:
    ; remove file descriptor from stack
    add rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE

.error_level_default:
    mov word [r14 + KERNEL_LIBRARY_STRUCTURE.flags], EMPTY

    ; set error flag
    stc

    jmp .end