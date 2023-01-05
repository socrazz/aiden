kernel_init_ap:
    ; kernel environment variables / routines base address
    mov r8, qword [kernel_environment_base_address]

    ; switch to new kernel paging array
    mov rax, ~KERNEL_PAGE_mirror
    and rax, qword [r8 + KERNEL_STRUCTURE.page_base_address]
    mov cr3, rax

    ; reload global descriptor table
    lgdt [kernel_gdt_header]
    call kernel_init_gdt_reload

    ; change CPU ID to descriptor offset
    call kernel_lapic_id
    shl rax, STATIC_MULTIPLE_BY_16_shift
    add rax, KERNEL_GDT_STRUCTURE.tss

    ; preserve  tss offset
    push rax

    ; set pointer to TSS entry of this AP
    add rdi, qword [kernel_gdt_header + KERNEL_GDT_STRUCTURE_HEADER.address]
    add rdi, rax

    ; length of tss header
    mov ax, kernel_tss_header_end - kernel_tss_header
    stosw

    ; TSS header address
    mov rax, kernel_tss_header
    ; save bits (15..0)
    stosw
    shr rax, 16
    ; save bits (23..16)
    stosb

    ; fill task state segment with flags
    mov al, 10001001b
    stosb
    xor al, al
    stosb

    ; TSS header address
    shr rax, 8
    shr rax, 8
    stosd

    ; reserved 32 bytes of descriptor
    xor rax, rax
    stosd

    ; load tss descriptor for this ap
    ltr word [rsp]

    ; reload global descriptor table for idt
    lidt [kernel_idt_header]

    ; enable QXSAVE, OSFXSR support
    mov rax, cr4
    or rax, 1000000001000000000b
    mov cr4, rax

    ; enable X87, SSE, AVX support
    xor ecx, ecx
    xgetbv
    or eax, 10001001b
    xsetbv

    ; enable syscall / sysret (SCE but) support
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1b
    wrmsr

    ; set code / stack segment of syscall routine
    mov ecx, KERNEL_INIT_MSR_STAR
    mov edx, 0x00180008
    wrmsr

    ; set syscall entry routine
    mov rax, kernel_syscall
    mov ecx, KERNEL_INIT_AP_MSR_LSTAR
    mov rdx, kernel_syscall
    shr rdx, STATIC_MOVE_HIGH_TO_EAX_shift
    wrmsr

    ;  set eflags mask of entry routine
    ; disable interrupt and direction
    mov eax, KERNEL_EFLAGS_if | KERNEL_TASK_EFLAGS_df
    mov ecx, KERNEL_INIT_AP_MSR_EFLAGS
    xor edx, edx
    wrmsr

    ; set task in queue being processed by AP
    call kernel_lapic_id
    push qword [r8 + KERNEL_STRUCTURE.task_queue_address]

    ; insert into task cpu list at AP position
    shl rax, STATIC_MULTIPLE_BY_8_shift
    add rax, qword [r8 + KERNEL_STRUCTURE.task_ap_address]
    pop qword [rax]

    ; initialize LAPIC of current AP
    call kernel_lapic_ini

    ; reload ap cycle counte
    call kernel_lapic_reload
    
    ; accept pending interrupts
    call kernel_lapic_accept
    
    ; AP initialized
    inc qword [r8 + KERNEL_STRUCTURE.cpu_count]
    
    ; enable interrupt handling
    sti

    jmp $


