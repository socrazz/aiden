kernel_init_acpi:
    push rax
    push rbx
    push rcx
    push rsi
    push rdi
    
    cmp qword [kernel_limine_rsdp_request + LIMINE_RSDP_REQUEST.response], EMPTY
    je .error

    mov rsi, qword [kernel_limine_rsdp_request + LIMINE_RSDP_REQUEST.response]
    mov rsi, qword [rsi + LIMINE_RSDP_RESPONSE.address]
    
    cmp byte [rsi + KERNEL_INIT_ACPI_STRUCTURE_RSDP_OR_XSDP_HEADER.revision], EMPTY
    jne .extended

    push rsi
    
    ; information acpi version
    mov rsi, kernel_acpi_standard
    call driver_serial_string

    pop rsi

    ; pointer 2 RSDT header 
    mov edi, dword [rsi + KERNEL_INIT_ACPI_STRUCTURE_RSDP_OR_XSDP_HEADER.rsdt_address]

    mov ecx, dword [edi + KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.length]
    sub ecx, KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.SIZE
    shr ecx, STATIC_DWORD_SIZE_shift

    ; move pointer to first entry of rsdt table
    add edi, KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.SIZE

.rsdt_entry:
    mov esi, dword [edi]
    call .parse

    ; next entry from rsdt table
    add edi, STATIC_DWORD_SIZE_byte

    dec ecx
    jnz .rsdt_entry

.extended:
    push rsi

    mov rsi, kernel_acpi_extended
    call driver_serial_string

    pop rsi
    mov rdi, qword [rsi + KERNEL_INIT_ACPI_STRUCTURE_RSDP_OR_XSDP_HEADER.xsdt_address]

    mov ecx, dword [edi + KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.length]
    sub ecx, KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.SIZE
    shr ecx, STATIC_DWORD_SIZE_shift
    
    ; move pointer to first entry rsdt table
    add edi, KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.SIZE

.xsdt_entry:
    mov rsi, qword [rdi]
    call .parse

    add rdi, STATIC_DWORD_SIZE_byte

    dec rcx
    jnz .xsdt_entry

.acpi_end:
    cmp qword [r8 + KERNEL_STRUCTURE.lapic_base_address], EMPTY
    je .error

    mov rsi, kernel_acpi_lapic
    call driver_serial_string
    mov rax, qword [r8 + KERNEL_STRUCTURE.lapic_base_address]
    mov ebx, STATIC_NUMBER_SYSTEM_hexadecimal
    call driver_serial_value

    ; if i/o apic controller is  available
    cmp qword [r8 + KERNEL_STRUCTURE.io_apic_base_address], EMPTY
    je .error

    ; show info i/o
    mov rsi, kernel_acpi_io_apic
    call driver_serial_string
    mov rax, qword [r8 + KERNEL_STRUCTURE.io_apic_base_address]
    mov ebx, STATIC_NUMBER_SYSTEM_hexadecimal
    call driver_serial_value

    ; set to original register
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax

    ret

.parse:
    dword [rsi + KERNEL_INIT_ACPI_STRUCTURE_MADT.madt + KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.signature], "APIC"
    je .madt

.madt:
    push rax
    push rcx
    push rsi
    
    mov eax, dword [rsi + KERNEL_INIT_ACPI_STRUCTURE_MADT.lapic_address]
    mov dword [r8 + KERNEL_STRUCTURE.lapic_base_address], eax

    mov ecx, dword [rsi + KERNEL_INIT_ACPI_STRUCTURE_MADT.madt + KERNEL_INIT_ACPI_STRUCTURE_DEFAULT.length]
    sub ecx, KERNEL_INIT_ACPI_STRUCTURE_MADT.SIZE

    add rsi, KERNEL_INIT_ACPI_STRUCTURE_MADT.SIZE

.madt_entry:
    cmp byte [rsi + KERNEL_INIT_ACPI_STRUCTURE_MADT_ENTRY.type], KERNEL_INIT_ACPI_MADT_ENTRY_TYPE_io_apic
    je .madt_io_apic

.madt_next:
    movzx eax, byte [rsi + KERNEL_INIT_ACPI_STRUCTURE_MADT_ENTRY.length]
    add rsi, rax

    sub rcx, rax
    jnz .madt_entry

    pop rsi
    pop rcx
    pop rax

    ret

.madt_io_apic:
    cmp dword [rsi + KERNEL_INIT_ACPI_STRUCTURE_IO_APIC.gsib], EMPTY
    jne .madt_next

    mov eax, dword [rsi + KERNEL_INIT_ACPI_STRUCTURE_IO_APIC.base_address]
    mov dword [r8 + KERNEL_STRUCTURE.io_apic_base_address], eax

    jmp .madt_next

.error:
    mov rsi, kernel_log_rsdp
    call driver_serial_string

    jmp $
