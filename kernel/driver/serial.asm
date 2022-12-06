driver_serial:
    push rax
    push rdx

    mov al, 0x00
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.interrupt_enable_or_divisor_high
    out dx, al

    mov al, 0x80
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.line_control_or_dlab
    out dx, al
    
    mov al, 0x03
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.data_or_divisor_low
    out dx, al
    mov al, 0x00
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.interrupt_enable_or_divisor_high
    out dx, al

    ; set 8 bit sign for no parity, 1 stop bit
    mov al, 0x03
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.line_control_or_dlab
    out dx, al
    
    mov al, 0xC7
    mov dl, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.interrupt_identification_or_fifo
    out dx, al

    mov al, 0x0B
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.modem_control
    out dx, al

    ; restore original register
    pop rdx
    pop rax

    ret

driver_serial_char:
    push rdx
    call driver_serial_ready
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.data_or_divisor_low
    out dx, al
    pop rdx
    ret

driver_serial_ready:
    push rax
    push rdx
    mov dx, DRIVER_SERIAL_PORT_COM1 + DRIVER_SERIAL_STRUCTURE_register.line_status

.loop:
    in al, dx
    test al, 01100000b
    jz .loop

    pop rdx
    pop rax
    ret

driver_serial_string:
    push rax
    push rsi

.loop:
    lodsb
    test al, al
    jz .end

    call driver_serial_char
    jmp .loop

.end:
    pop rsi
    pop rax

    ret

driver_serial_valu:
    push rax
    push rdx
    push rbp

    mov rbp, rsp

.loop:
    xor edx, edx
    div rbx

    add dl, STATIC_ASCII_DIGIT_0
    push rdx

    test rax, rax
    jnz .loop

.return:
    cmp rsp, rbp
    je .end

    pop rax
    cmp  al, STATIC_ASCII_DIGIT_0
    jb .no

    add al, 0x07

.no:
    call driver_serial_char
    jmp .return

.end:
    pop rbp
    pop rdx
    pop rax

    ret
