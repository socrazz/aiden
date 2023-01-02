align 0x08, db 0x00

kernel_task:
    ; turn off interrupt flag
    cli

    ; turn off direction flag
    cld
    
    ; keep original register
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov rbp, KERNEL_TASK_STACK_pointer
    FXSAVE64 [rbp]

    ; kernel environment variables / routines base address
    mov r8, qword [kernel_environment_base_address]

    ; retrieve CPU from LAPIC
    mov rbx, qword [r8 + KERNEL_STRUCTURE.lapic_base_address]
    mov ebx, qword [rbx + KERNEL_LAPIC_STRUCTURE.id]
    ; move ID at a begining of eax register
    shr ebx, 24
    
    ; get pointer to current task of AP
    mov r9, qword [r8 + KERNEL_STRUCTURE.task_ap_address]
    mov r10, qword [r9 + rbx * STATIC_PTR_SIZE_byte]

    test r10, r10
    jnz .ok

    ; set initialize task as closed
    mov r10, qword [r8 + KERNEL_STRUCTURE.task_queue_address]

.ok:
    ; save tasks current task pointer
    mov qword [r10 + KERNEL_TASK_STRUCTURE.rsp], rsp

    ; set flags of current task as free for execution by next CPU
    and word [r10 + KERNEL_TASK_STRUCTURE.flags], ~KERNEL_TASK_FLAG_exec

.lock:
    ; reqquest an excluive access
    mov al, LOCK
    lock xchg byte [r8 + KERNEL_STRUCTURE.task_queue_semaphore], al

    test al, al
    jnz .lock

    ; calculate task queue size
    mov rax, KERNEL_TASK_STRUCTURE.SIZE
    mov ecx, KERNEL_TASK_limit
    mul rcx

    ; set queue limit pointer
    add rax, qword [r8 + KERNEL_STRUCTURE.task_queue_address]

.next:
    ; move pointer to next task in queue
    add r10, KERNEL_TASK_STRUCTURE.SIZE
    
    cmp r10, rax
    jb .check

    ; start searching from beginning
    mov r10, qword [r8 + KERNEL_STRUCTURE.task_queue_address]

.check:
    test word [r10 + KERNEL_TASK_STRUCTURE.flags], KERNEL_TASK_FLAG_active
    jz .next

    ; check task can be execute or not
    test word [r10 + KERNEL_TASK_STRUCTURE.flags], KERNEL_TASK_FLAG_exec
    jnz .next

    or word [r10 + KERNEL_TASK_STRUCTURE.flags], KERNEL_TASAK_FLAG_EXEC

    mov byte [r8 + KERNEL_STRUCTURE.task_queue_semaphore], UNLOCK

    ; [restore]
    
    ; set pointer to current task for AP
    mov qword [r9 + rbx * STATIC_PTR_SIZE_byte], r10
    
    ; restore tasks stack pointer
    mov rsp, qword [r10 + KERNEL_TASK_STRUCTURE.rsp]

    ; restore task page arrays
    mov rax, qword [r10 + KERNEL_TASK_STRUCTURE.cr3]
    mov cr3, rax

    ; reload CPU cycle counter in APIC controller
    mov rax, qword [r8 + KERNEL_STRUCTURE.lapic_base_address]
    mov dword [rax + KERNEL_LAPIC_STRUCTURE.tic], KERNEL_LAPIC_Hz

    ; accept current interrupt call
    mov dword [rax + KERNEL_LAPIC_STRUCTURE.eoi], EMPTY

    ; restore "floating point" register
    mov rbp, KERNEL_TASK_STACK_pointer
    FXRSTOR64 [rbp]
    
    ; restore
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    
    iretq

kernel_task_add:
    push rax
    push rcx
    push rsi
    push rdi
    push r8

    ; kernel environment variables / routines base address
    mov r8, qword [kernel_environment_base_address]

    ; search for free entry from beginning
    mov rax, KERNEL_TASK_limit
    mov r10, qword [r8 + KERNEL_STRUCTURE.task_queue_address]

.loop:
    lock bts word [r10 + KERNEL_TASK_STRUCTURE.flags], KERNEL_TASK_FLAG_secured_bit
    jnc .found

    ; move pointer to next task in queue
    add r10, KERNEL_TASK_STRUCTURE.SIZE

    dec rax
    jnz .loop

    xor r10, r10
    
    jmp .end

.found:
    ; set process ID
    call kernel_task_id_new
    mov qword [r10 + KERNEL_TASK_STRUCTURE.pid], rax

    ; retrieve parent ID
    call kernel_task_id_parent
    mov qword [r10 + KERNEL_TASK_STRUCTURE.pid_parent], rax

    ; process name
    cmp rcx, KERNEL_TASK_NAME_limit
    jbe .proper_length

    ; fix name length
    mov rcx, KERNEL_TASK_NAME_limit

.proper_length:
    ; length of process name
    mov qword [r10 + KERNEL_TASK_STRUCTURE.length], rcx

    mov rdi, r10
    add rdi, KERNEL_TASK_STRUCTURE.name
    rep movsb

    ; number of task inside queue
    inc qword [r8 + KERNEL_STRUCTURE.task_count]

.end:
    ; restore original register
    pop r8
    pop rdi
    pop rsi
    pop rcx
    pop rax

    ret

kernel_task_current:
    push rax
    pushf

    ; turn off interrutps
    ; caannot allow task switch
    ; when looking for current task point
    cli

    ; retrieve CPU id
    call kernel_lapic_id

    ; set pointer to current taask of CPU
    mov r9, qword [kernel_task_environment_base_address]
    mov r9, qword [r9 + KERNEL_STRUCTURE.task_ap_address]
    mov r9, qword [r9 + rax * STATIC_PTR_SIZE_byte]

    popf
    pop rax

    ret

kernel_task_id_new:
    push r8

    ; kernel environment variabel / routines base address
    mov r8, qword [kernel_environment_base_address]

    ; generate new ID 
    inc qword [r8 + KERNEL_STRUCTURE.task_id]

    mov rax, qword [r8 + KERNEL_STRUCTURE.task_id]

    ; restore original register
    pop r8
    ret

kernel_task_id_parent:
    push r9
    ; retrieve pointer to current task descriptor
    call kernel_task_current

    ; return parent ID
    mov rax, qword [r9 + KERNEL_TASK_STRUCTURE.pid]

    pop r9
    ret