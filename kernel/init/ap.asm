kernel_init_ap:
    mov r8, qword [kernel_environment_base_address]
    
    mov rax, ~KERNEL_PAGE_mirror
    and rax, qword [r8 + KERNEL_STRUCTURE.page_base_address]
    mov cr3, rax

    lgdt [kernel_gdt_header]
    call kernel_init_gdt_reload

    ; change cpu ID to descriptor offset
    call kernel_lapic_id
    shl rax, STATIC_MULTIPLE_BY_16_shift
    add rax, KERNEL_GDT_STRUCTURE.tss

    ; preserve TSS offset
    push rax

    ; set pointer to TSS entry of AP
    mov rdi, qword [kernel_gdt_header + KERNEL_GDT_STRUCTURE_HEADER.address]]
    add rdi, rax

    mov ax, kernel_tss_header_end - kernel_tss_header
    stosw

    ; TSS Header addres
    mov rax, kernel_tss_header
    stosw
    shr rax, 16
    stosb

    mov al, 10001001b
    stosb
    xor al, al
    stosb

    shr rax, 8
    stosb
    shr rax, 8
    stosd

    ; reserved 32 byte of descriptor
    xor rax, rax
    stosd

    ; load TSS descriptor for this AP
    ltr word [rsp]

    ; reload global descriptor table
    lidt [kernel_idt_header]

    ; enable osxsave osfxsr support
    ; https://www.felixcloutier.com/x86/cpuid
    mov rax, cr4
    or rax, 1000000001000000000b
    mov cr4, rax

    xor ecx, ecx
    xgetbv
    or eax, 111b
    xsetbv

    ; enable syscall/sysret support
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1b
    wrmsr

    ; set code segment of syscall routine
    mov ecx, KERNEL_INIT_AP_MSR_STAR
    mov edx, 0x00180008
    wrmsr

    mov rax, kernel_syscall
    mov ecx, KERNEL_INIT_AP_MSR_LSTAR
    mov rdx, kernel_syscall
    shr rdx, STATIC_MOVE_HIGH_TO_EAX_shift
    wrmsr

    mov eax, KERNEL_TASK_EFLAGS_df
    mov ecx, KERNEL_INIT_AP_MSR_EFLAGS
    xor edx, edx
    wrmsr

    ; set task in queue being process by AP
    call kernel_lapic_id
    push qword [r8 + KERNEL_STRUCTURE.task_queue_address]

    ; insert into task cpu list at AP position
    shl rax, STATIC_MULTIPLE_BY_8_shift
    add rax, qword [r8 + KERNEL_STRUCTURE.task_cpu_addres]
    pop qword [rax]

    call kernel_lapic_init

    ; reload AP counter
    call kernel_lapic_reload

    ; acc pending interrupts
    call kernel_lapic_accept

    inc qword [r8 + KERNEL_STRUCTURE.cpu_count]

    ; enable interrupt handling
    sti

    jmp $
