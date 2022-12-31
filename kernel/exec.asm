kernel_exec:
    push rax
    push rbx
    push rdx
    push rdi
    push rbp
    push r8
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rsi
    push rcx

    mov r8, qword [kernel_environment_base_address]

    mov qword [rbp + KERNEL_EXEC_STRUCTURE.pid], EMPTY

    ; file descriptor
    sub rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE
    mov rbp, rsp
    
    ; get file properties
    movzx eax, byte [r8 + KERNEL_STRUCTURE.storage_root_id]
    call kernel_storage_file

    ; get prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.task_or_status], LIB_SYS_ERROR_file_not_found

    ; checking file found
    cmp qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.id], EMPTY
    je .end

    ; prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.task_or_status], LIB_SYS_ERROR_file_not_found

    ; preparing space for file content
    mov rcx, qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.size_byte]
    add rcx, ~STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc
    ; no memory
    jc .end

    ; load file content into prepared space
    mov rsi, qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.id]
    call kernel_storage_read

    ; preserve file size in pages and location
    mov r12, rcx
    mov r13, rdi
    
    ; prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.task_or_status], LIB_SYS_ERROR_file_not_found

    ; checking if file have proper ELF header
    call lib_elf_check
    jc .error_level_file

    ; check prepare error code
    cmp byte [rdi + LIB_ELF_STRUCTURE.type], LIB_ELF_TYPE_executable
    jne .error_level_file

    ; prepare error code
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.task_or_status], LIB_SYS_ERROR_undefined

    ; load dependend lib
    call kernel_library_import
    jc .error_level_file

    ; connect libraries to file executable
    call kernel_library_link

    ; register new task on queue
    mov rcx, qword [rsp + KERNEL_STORAGE_FILE.SIZE]
    mov rsi, qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + STATIC_PTR_SIZE_byte]
    call kernel_task_add
    jc .error_level_file

    ; paging array of new process
    ; prepare error code
    mov	qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.task_or_status], LIB_SYS_ERROR_exec_not_executable

    ; make space for the process paging table
    call kernel_memory_alloc_page
    jc .error_level_task

    ; update task entry paging array
    mov qword [r10 + KERNEL_TASK_STRUCTURE.cr3], rdi
    
    ; describe the spaced under context stack of process
    mov rax, KERNEL_TASK_STACK_address
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write | KERNEL_PAGE_FLAG_process
    mov ecx, KERNEL_TASK_STACK_SIZE_page
    mov r11, rdi
    call kernel_page_alloc
    jc .error_level_page

    mov qword [r10 + KERNEL_TASK_STRUCTURE.rsp], KERNEL_TASK_STACK_pointer - KERNEL_EXEC_STRUCTURE_RETURN.SIZE

    ; prepare exception exit mode on context stack of process
    mov rax, KERNEL_TASK_STACK_pointer - STATIC_PAGE_SIZE_byte
    call kernel_page_address

    ; move pointer to return descriptor
    add rdx, STATIC_PAGE_SIZE_byte - KERNEL_EXEC_STRUCTURE_RETURN.SIZE
    
    ; set first instruction executed by process
    mov rax, qword [r13 + LIB_ELF_STRUCTURE.program_entry_position]
    mov qword [rdx + KERNEL_EXEC_STRUCTURE_RETURN.rip], rax

    ; code descriptor
    mov qword [rdx + KERNEL_EXEC_STRUCTURE_RETURN.cs], KERNEL_GDT_STRUCTURE.cs_ring3 | 0x03

    ; default processor state flag
    mov qword [rdx + KERNEL_EXEC_STRUCTURE_RETURN.eflags], KERNEL_TASK_EFLAGS_default

    ; stack descriptor
    mov qword [rdx + KERNEL_EXEC_STRUCTURE_RETURN.ss], KERNEL_GDT_STRUCTURE.ds_ring3 | 0x03

    ; default stack pointer
    mov rax, KERNEL_EXEC_STACK_pointer
    mov qword [rdx + KERNEL_EXEC_STRUCTURE_RETURN.rsp], rax

    ; stack descriptor
    mov qword [rdx + KERNEL_EXEC_STRUCTURE_RETURN.ss], KERNEL_GDT_STRUCTURE.ds_ring3 | 0x03

    ; stack
    ; describe the space under context stack of process
    mov rax, KERNEL_EXEC_STACK_address
    or bx, KERNEL_PAGE_FLAG_user
    mov ecx, STATIC_PAGE_SIZE_PAGE
    call kernel_page_alloc
    jc .error_level_page

    ; load program segment in place
    ; number of program header
    movzx ecx, word [r13 + LIB_ELF_STRUCTURE.header_entry_count]

    ; beginning of header section
    mov rdx, qword [r13 + LIB_ELF_STRUCTURE.header_table_position]
    add rdx, r13

.elf_header:
    ; ignore empty header
    cmp dword [rdx + LIB_ELF_STRUCTURE_HEADER.type], EMPTY
    je .elf_header_next
    cmp qword [rdx + LIB_ELF_STRUCTURE_HEADER.memory_size], EMPTY
    je .elf_header_next

    cmp dword [rdx + LIB_ELF_STRUCTURE_HEADER.type], LIB_ELF_HEADER_TYPE_load
    jne .elf_header_next

    ; calculate segment address
    mov r14, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    and r14, STATIC_PAGE_mask

    ; calculate segment size in pages
    mov rax, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    and rax, STATIC_PAGE_mask
    mov r15, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]
    add r15, qword [rdx + LIB_ELF_STRUCTURE_HEADER.segment_size]
    sub r15, rax

    ; align up to next page boundary
    add r15, STATIC_PAGE_SIZE_byte - 1
    shr r15, STATIC_PAGE_SIZE_shift

    ; preserve original register
    push rcx

    ; assign memory space for segment
    mov rcx, r15
    call kernel_memory_alloc

    ; restore original register
    pop rcx

    ; assign memory space for segment
    mov rcx, r15
    call kernel_memory_alloc

    pop rcx

    ; check if no enough memory
    jc .error_level_page

    ; source
    mov rsi, r13
    add rsi, qword [rdx + LIB_ELF_STRUCTURE_HEADER.segment_offset]

    ; preserve segment pointer and original register
    push rcx
    push rdi

    and qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address], ~STATIC_SIZE_mask
    add rdi, qword [rdx + LIB_ELF_STRUCTURE_HEADER.virtual_address]

    ; copy file segment in place
    mov rcx, qword [rdx + LIB_ELF_STRUCTURE_HEADER.segment_size]
    rep movsb

    ; restore segment pointer
    pop rsi

    ; map segment to process paging array
    mov rax, r14
    mov rcx, r15
    sub rsi, qword [kernel_page_mirror]
    call kernel_page_map

    pop rcx

    jc .error_level_page

.elf_header_next:
    ; move pointer to next entry
    add rdx, LIB_ELF_STRUCTURE_HEADER.SIZE

    ; end of header table
    dec rcx
    jnz .elf_header

    ; assign memory space for binary memory map with same size
    ; as kernel
    mov rcx, qword [r8 + KERNEL_STRUCTURE.page_limit]
    shr rcx, STATIC_DIVIDE_BY_8_shift
    add rcx, ~STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc

    ; preserve binary memory size and alocation
    push rdi
    push rcx

    ; fill memory map with available pages
    mov rax, STATIC_MAX_UNSIGNED
    shl rcx, STATIC_MULTIPLE_BY_512_shift
    rep stosq

    pop rcx

    ; everything before binary map is not available for
    ; process mark that space as unavailable

    ; first available page number
    mov rax, r14
    shr rax, STATIC_PAGE_SIZE_shift
    add rax, rcx
    
    ; resore memory map location
    pop rsi

.reserved:
    btr qword [rsi], rax
    dec rax
    jns .reserved

    ; map binary memory map to process paging array
    mov rax, r15
    shl rax, STATIC_PAGE_SIZE_shift
    add rax, r14
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write | KERNEL_PAGE_FLAG_process
    shl rsi, 17
    shr rsi, 17
    call kernel_page_map

    ; store binary memory map address inside task properties
    mov qword [r10 + KERNEL_TASK_STRUCTURE.memory_map], rax

    ; mapping kernel space to process
    call kernel_page_merge

    ; mark task as ready
    or word [r10 + KERNEL_TASK_STRUCTURE.flags], KERNEL_TASK_FLAG_active | KERNEL_TASK_FLAG_init

    ; return PID and pointer to task on queue
    push qword [r10 + KERNEL_TASK_STRUCTURE.pid]
    pop qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.pid]
    mov qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE + KERNEL_EXEC_DESCRIPTOR_offset + KERNEL_EXEC_STRUCTURE.task_or_status], r10

.end:
    ; remove file descriptor from stack
    add rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE

    ; restore original registers
    pop rcx
    pop rsi
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r8
    pop rbp
    pop rdi
    pop rdx
    pop rbx
    pop rax

    ret

.error_level_page:
    call kernel_page_deconstruction

.error_level_task:
    mov word [r10 + KERNEL_TASK_STRUCTURE.eflags], EMPTY

.error_level_file:
    ; release space of loaded file
    mov rcx, r12
    mov rdi, r13
    call kernel_memory_release

    jmp .end
