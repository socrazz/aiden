kernel_init_framebuffer:
    push rax
    push rsi

    ; check framebuffer is available
    cmp qword [kernel_limine_framebuffer_request + LIMINE_FRAMEBUFFER_REQUEST.response], EMPTY
    je .error

    mov rsi, qword [kernel_limine_framebuffer_request + LIMINE_FRAMEBUFFER_REQUEST.response]
    cmp qword [rsi + LIMINE_FRAMEBUFFER_RESPONSE.framebuffer_count], 1
    je .framebuffer

.error:
    mov rsi, kernel_log_framebuffer
    call driver_serial_string

    jmp $

.framebuffer:
    mov rsi, qword [rsi + LIMINE_FRAMEBUFFER_RESPONSE.framebuffer]
    mov rsi, qword [rsi]

    ; store properties of framebuffer
    ; base address
    mov rax, qword [rsi + LIMINE_FRAMEBUFFER.address]
    mov qword [r8 + KERNEL_STRUCTURE.framebuffer_base_address], rax

    ; width in pixel
    mov ax, word [rsi + LIMINE_FRAMEBUFFER.width]
    mov word [r8 + KERNEL_STRUCTURE.framebuffer_width_pixel], ax
    
    ; height in pixel
    mov ax, word [rsi + LIMINE_FRAMEBUFFER.height]
    mov word [r8 + KERNEL_STRUCTURE.frambuffer_height_pixel], ax

    ; scanline in bytes
    mov eax, dword [rsi + LIMINE_FRAMEBUFFER.pitch]
    mov dword [r8 + KERNEL_STRUCTURE.framebuffer_scanline_byte], eax

    pop rsi
    pop rax

    ret