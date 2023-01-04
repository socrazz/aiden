kernel_lapic_accept:
    push rax

    ; lapic controller base address
    mov rax, qword [kernel_environment_base_address]
    mov rax, qword [rax + kernel_structure.lapic_base_address]
    
    ; accept currently pending interrupt
    mov dword [rax + KERNEL_LAPIC_STRUCTURE.eoi], EMPTY
    
    pop rax

    ret

kernel_lapic_id:
    ; kernel environment variable / routines base address
    mov rax, qword [kernel_environment_base_address]

    ; retrieve CPU ID from LAPIC
    mov rax, qword [rax + KERNEL_STRUCTURE.lapic_base_address]
    mov eax, dword [rax + KERNEL_LAPIC_STRUCTURE.id]
    shr eax, 24

    ; return from routine
    ret

kernel_lapic_init:
    push rax
    push rdi

    ; kernel environment variables / routines base address
    mov rdi, qword [kernel_environment_base_address]
    mov rdi, qword [rdi + KERNEL_STRUCTURE.lapic_base_address]

    ; turn off task priority and priority sub class
    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.tp], EMPTY
    
    ; turn on flat mode
    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.df], KERNEL_LAPIC_DF_FLAG_flat_mode

    ; all logical / bsp processor gets  interrup
    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.ld], KERNEL_LAPIC_LD_FLAG_target_cpu

    ; enable APIC controller on the bsp / logical processor
    mov eax, dword [rdi + KERNEL_LAPIC_STRUCTURE.siv]
    or eax, KERNEL_LAPIC_SIV_FLAG_enable_apic | KERNEL_LAPIC_SIV_FLAG_spurious_vector3
    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.siv], eax

    ; trun on internal interrupts time on APIC controller of BSP/logical processor
    mov eax, dword [rdi + KERNEL_LAPIC_STRUCTURE.lvt]
    and eax, KERNEL_LAPIC_LVT_TR_FLAG_mask_interrupts
    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.lvt], eax

    ; number of hardware interrupt at the end of the timer
    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.lvt], KERNEL_LAPIC_IRQ_number

    mov dword [rdi + KERNEL_LAPIC_STRUCTURE.tdc], KERNEL_LAPIC_TDC_divide_by_1

    pop rdi
    pop rax
    ret

kernel_lapic_reload:
    push rax

    ; LAPIC controller base address
    mov rax, qword [kernel_environment_base_address]
    mov rax, qword [rax + KERNEL_STRUCTURE.lapic_base_address]

    ; wake up internal interrupt after KERNEL_LAPIC_Hz cycles
    mov dword [rax + KERNEL_LAPIC_STRUCTURE.tic], KERNEL_LAPIC_Hz
    
    pop rax

    ret