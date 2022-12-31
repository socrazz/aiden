kernel_init_task:
    push rax
    push rbx
    push rcx
    push rdi

    mov ecx, ((KERNEL_TASK_limit * KERNEL_TASK_STRUCTURE.SIZE) + ~STATIC_PAGE_mask) >> STATIC_PAGE_SIZE_shift
    call kernel_memory_alloc

    ; save pointer to task queue
    mov qword [r8 + KERNEL_STRUCTURE.task_queue_address], rdi

    mov word [rdi + KERNEL_TASK_STRUCTURE.flags], KERNEL_TASK_FLAG_secured

    ; entry paging array
    mov rax, qword [r8 + KERNEL_STRUCTURE.page_base_address]
    mov qword [rdi + KERNEL_TASK_STRUCTURE.cr3], rax

    ; kernel memory map
    mov rax, qword [r8 + KERNEL_STRUCTURE.memory_base_address]
    mov qword [rdi + KERNEL_TASK_STRUCTURE.memory_map], rax

    ; remember pointer to first task queue
    push rdi

    ; assume that only one cpu is available
    mov ecx, 1

    cmp qword [kernel_limine_smp_request + LIMIME_SMP_REQUEST.response], EMPTY
    je .one_to_rule_all

    ; retrieve available cpu on host
    mov rcx, qword [kernel_limine_smp_request + LIMINE_SMP_REQUEST.response]
    mov rcx, qword [rcx + LIMINE_SMP_RESPONSE.cpu_count]

.one_to_rule_all:
    ; calculating cpu listing size in pages
    shl rcx, STATIC_MULTIPLE_BY_8_shift
    add rcx, ~STATIC_PAGE_mask
    add rcx, STATIC_PAGE_mask
    shr rcx, STATIC_PAGE_SIZE_shift

    ; assign space for task list and store
    call kernel_memory_alloc
    mov qword [r8 + KERNEL_STRUCTURE.task_ap_address, rdi]

    ; mark in processor task list, BSP processor with its kernel task
    call kernel_lapic_id
    pop qword [rdi + rax * STATIC_PTR_SIZE_byte]

    ; attach task swwitch interrupt routine handler
    mov rax, kernel_task
    mov bx, KERNEL_IDT_TYPE_irq
    mov ecx, KERNEL_TASK_irq
    call kernel_idt_update

    pop rdi
    pop rcx
    pop rbx
    pop rax

    ret

