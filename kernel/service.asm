section .rodata

align 0x08, db 0x00
kernel_service_list:
    dq	kernel_service_framebuffer
	dq	kernel_service_memory_alloc
	dq	kernel_service_memory_release
	dq	kernel_service_task_pid
	dq	kernel_service_driver_mouse
	dq	kernel_service_storage_read
    dq  kernel_service_exec
kernel_service_list_end:
section .text

kernel_service_exec:
    push rcx
    push rsi
    push rdi
    push r8

    xchg bx, bx

    ; kernel environment variable / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; prepare exec decriptor
    sub rsp, KERNEL_EXEC_STRUCTURE.SIZE
    ; pointer of file descriptor
    mov rbp, rsp
    
    ; execute file from path
    mov rcx, rsi
    mov rsi, rdi
    ; call kernel_exec

    ; remove exec descriptor
    add rsp, KERNEL_EXEC_STRUCTURE.SIZE

    pop r8
    pop rdi
    pop rsi
    pop rcx

    ret
    

kernel_service_driver_mouse:
    push rax
    push r8

    ; kernel environment variable / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; share information about mouse location and status
    mov ax, word [r8 + KERNEL_STRUCTURE.driver_ps2_mouse_x]
    mov word [rdi + LIB_SYS_STRUCTURE_MOUSE.x], ax,
    mov ax, word [r8 + KERNEL_STRUCTURE.driver_ps2_mouse_y]
    mov word [rdi + LIB_SYS_STRUCTURE_MOUSE.y], ax
    mov al, byte [r8 + KERNEL_STRUCTURE.driver_ps2_mouse_x]
    mov byte [rdi + LIB_SYS_STRUCTURE_MOUSE.x], al

    pop r8
    pop rax

    ret

kernel_service_framebuffer:
    push rax
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    push r11

    ; kernel environment variabel / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; witdh in pixel
    mov ax, word [r8 + KERNEL_STRUCTURE.framebuffer_width_pixel]
    mov word [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.width_pixel], ax

    ; height in pixel
    mov	ax,	word [r8 + KERNEL_STRUCTURE.framebuffer_height_pixel]
	mov	word [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.height_pixel], ax

    mov	eax,	dword [r8 + KERNEL_STRUCTURE.framebuffer_scanline_byte]
	mov	dword [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.scanline_byte], eax
    
    ; frambuffer manager
    mov rax, qword [r8 + KERNEL_STRUCTURE.framebuffer_pid]
    
    ; framebuffer manager
    test rax, rax
    jnz .return

    ; retrieve pointer to current task descriptor
    call kernel_task_current

    ; calculate size of framebuffer space
    mov eax, dword [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.scanline_byte]
    movzx ecx, word [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.height_pixel]

    ; convert to pages
    add rax, ~STATIC_PAGE_mask
    shr rax, STATIC_PAGE_SIZE_shift

    ; share framebuffer memory spce with process
    xor ecx, ecx
    xchg rcx, rax
    mov rsi, qword [r8 + KERNEL_STRUCTURE.framebuffer_base_address]
    mov rsi, qword [r9 + KERNEL_TASK_STRUCTURE.cr3]
    call kernel_memory_share
    jc .return

    mov qword [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.base_addres], rax

    mov rax, qword [r9 + KERNEL_TASK_STRUCTURE.pid]

.return:
    mov qword [rdi + LIB_SYS_STRUCTURE_FRAMEBUFFER.pid], rax

    pop r11
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rax

    ret

kernel_service_memory_alloc:
    push rbx
    push rcx
    push rsi
    push rdi
    push r8
    push r9
    push r11

    ; convert size to pages
    add rdi, ~STATIC_PAGE_mask
    shr rdi, STATIC_PAGE_SIZE_shift

    ; retrieve pointer to current task descriptor
    call kernel_task_current
    
    ; set pointer of proces paging array
    mov r11, qword [r9 + KERNEL_TASK_STRUCTURE.cr3]

    ; acquire memory space from proces memory map
    mov r9, qword [r9 + KERNEL_TASK_STRUCTURE.memory_map]
    mov rcx, rdi
    call kernel_memory_acquire
    jc .error

    ; convert first page number to logical address 
    shl rdi, STATIC_PAGE_SIZE_shift

    ; assign pages to allocated memory in process space
    mov rax, rdi
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write | KERNEL_PAGE_FLAG_user | KERNEL_PAGE_FLAG_process
    call kernel_page_alloc
    jnc .end

    mov rsi, rcx
    call kernel_service_memory_release

.error:
    xor eax, eax

kernel_service_release:
    push rax
    push rcx
    push rsi
    push rdi
    push r9
    push r11

    ; retrieve pointer to current task descriptor
    call kernel_task_current

    ; convert bytes to pages
    add rsi, ~STATIC_PAGE_mask
    add rsi, STATIC_PAGE_SIZE_shift

    ; release space from paging array of process
    mov rax, rdi
    mov rcx, rsi
    mov r11, qword [r9 + KERNEL_TAK_STRUCTURE.cr3]
    call kernel_page_release
    
    pop r11
    pop r9
    pop rdi
    pop rsi
    pop rcx
    pop rax

    ret

kernel_service_task_pid:
    push r9
    
    ; retrieve pointer to current task descriptor
    call kernel_task_current

    ; set pointer of process array
    mov rax, qword [r9 + KERNEL_TASK_STRUCTURE.pid]

    ; restore again to original register
    pop r9

    ret

kernel_service_storage_read:
    push rax
    push rbx
	push rcx
	push rsi
	push rbp
	push r8
	push r9
	push r11
	push rdi

    ; kernel environment variabel / routine base address
    mov r8, qword [kernel_environment_base_address]

    ; prepare space for file descriptor
    sub rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE
    mov rbp, rsp

    ; get file properties
    movzx eax, byte [r8 + KERNEL_STRUCTURE.storage_root_id]
    movzx ecx, byte [rdi + LIB_SYS_STRUCTURE_STORAGE.length]
    lea rsi, [rdi + LIB_SYS_STRUCTURE_STORAGE.name]
    call kernel_storage_file

    cmp qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.id], EMPTY
    je .end

    ; prepare space for file content
    mov rcx, qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.size_byte]
    add rcx, ~STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc
    jc .end

    ; load file content into prepared space
    mov rsi, qword [rbp + KERNEL_STROAGE_STRUCTURE_FILE.id]
    call kernel_storage_read
    
    ; retrieve current task pointer
    call kernel_task_current

    ; preserve file content address
    sub rdi, qword [kernel_page_mirror]
    mov rsi, rdi

    ; aquire memory inside process space for file
    mov r9, qword [r9 + KERNEL_TASK_STRUCTURE.memory_map]
    call kernel_memory_acquire
    jc .error

    ; map file content to process space
    mov rax, rdi
    ; convert page number to logical address
    shl rax, STATIC_PAGE_SIZE_shift
    mov bx, KERNEL_PAGE_FLAG_present | KERNEL_PAGE_FLAG_write | KERNEL_PAGE_FLAG_user | KERNEL_PAGE_FLAG_process
    ; task paging array
    mov r11, cr3
    call kernel_page_map
    ; if no enough memory
    jc .error

    ; restore file descriptor
    mov rdi, qword [rsp + KERNEL_STORAGE_STRUCTURE_FILE.SIZE]

    ; inform process about file location and size
    push qword [rbp + KERNEL_STORAGE_STRUCTURE_FILE.size_byte]
    pop qword [rdi + LIB_SYS_STRUCTURE_STROAGE.size_byte]
    mov qwiord [rdi + LIB_SYS_STRUCTURE_STORAGE.address], rax

    jmp .end

.error:
    ; releaes memory assigned for file
    mov rdi, rsi
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release

.end:
    ; remove file descriptor from stack
    add rsp, KERNEL_STORAGE_STRUCTURE_FILE.SIZE

    pop rdi
    pop r11
    pop r9
    pop r8
    pop rbp
    pop rsi
    pop rcx
    pop rbx
    pop rax

    ret