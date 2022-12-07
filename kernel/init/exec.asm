kernel_init_exec:
    push rcx
    push rsi

    ; execute init file
    mov ecx, KERNEL_EXEC_FILE_INIT_length
    mov rsi, kernel_exec_file_init

    pop rsi
    pop rcx
    
    ret