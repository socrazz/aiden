kernel_page_address:
    push rax
    push rcx
    push r11

    mov rdx, ~KERNEL_PAGE_mask
    and rax, rdx

    ; compute entry number of PML4 array
    xor edx, edx
    mov rcx, KERNEL_PAGE_PML3_SIZE_byte
    div rcx

    ; retrieve PML3 addres
    
    ; convert to logical address
    or r11, qword [kernel_page_mirror]
    mov r11, qword [r11 + rax * STATIC_QWORD_SIZE_byte]
    and r11, STATIC_PAGE_mask

    ; compute entry number of PML3 array
    
    ; restore rest of division
    mov rax, rdx
    mov rcx, KERNEL_PAGE_PML2_SIZE_byte
    xor edx, edx
    div rcx

    ; retrieve PML2 address
    
    ; convert to logical addres
    or r11, qword [kernel_page_mirror]
    mov r11, qword [r11 + rax * STATIC_QWORD_SIZE_byte]
    ; drop flags
    and r11, STATIC_PAGE_mask

    ; compute entry number of PML2 array
    
    ; restore rest of division
    mov rax, rdx
    mov rcx, KERNEL_PAGE_PML1_SIZE_byte
    ; higher of address part is not involved in
    ; calculation
    xor edx, edx
    div rcx

    ; retrieve PML1 address

    ; convert to logical address
    or r11 qword [kernel_page_mirror]
    ; drop flags
    and r11, STATIC_PAGE_mask

    ; compute entry number of PML1 array

    ; restore rest of division
    mov rax, rdx
    mov rcx, STATIC_PAGE_SIZE_byte
    xor edx, edx
    div rcx
    
    ; retrieve PML1 address

    ; convert to logical address
    or r11, qword [kernel_page_mirror]
    mov rdx, qword [r11 + rax * STATIC_QWORD_SIZE_byte]
    and rdx, STATIC_PAGE_mask

    ; convert again to logical address
    or rdx, qword [kernel_page_mirror]

    pop r11
    pop rcx
    pop rax

    ret


kernel_page_align_up:
    ; align page to next address
    and rdi, ~STATIC_PAGE_mask
    and rdi, STATIC_PAGE_mask

    ret


kernel_page_alloc:
    push rcx
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    ; prepare default paging structure
    call kernel_page_prepare
    jc .end

.next:
    cmp r12, KERNEL_PAGE_ENTRY_count
    jb .entry

    ; extend paging array
    call kernel_page_extend
    jc .end

.entry:
    ; requet page for PML1 entry
    call kernel_memory_alloc_page
    jc .end

    ; assign flags
    or di, bx

    ; regisster inside entry
    mov qword [r8 + r12 * STATIC_QWORD_SIZE_byte], rdi
    
    ; next entry from PML1 array
    inc r12
    
    dec rcx
    jnz .next

.end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rcx

    ret

kernel_page_clean:
    push rcx

    ; clean whole 1 page
    mov rcx, STATIC_PAGE_SIZE_page
    call .proceed

    pop rcx
    
    ret

.proceed:
    push rax
    push rdi

    ; clean area
    xor rax, rax
    shl rcx, STATIC_MULTIPLE_BY_512_shift
    rep stosq

    pop rdi
    pop rax

    ret

kernel_page_deconstruction:
    push rcx
    push rdi
    push r8
    push r9
    push r10
    push r11

    ; convert process paging array pointer to
    ; high half
    or r11, qword [kernel_page_mirror]
    
    ; first kernel entry in PML4 array
    xor ecx, ecx

.pml4:
    cmp qword [r11 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml4_next

    push rcx
    
    ; kernel PML3 array
    mov r10, qword [r11 + rcx * STATIC_PTR_SIZE_byte]
    or r10, qword [kernel_page_mirror]
    and r10, STATIC_PAGE_mask

    ; first kernel entry of PML3 array
    xor ecx, ecx

.pml3:
    cmp qword [r10 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml3_next

    push rcx
    
    ; kernel PML2 array
    mov r9, qword [r10 + rcx * STATIC_PTR_SIZE_byte]
    or r9, qword [kernel_page_mirror]
    and r9, STATIC_PAGE_mask

    ; first kernel entry of PML2 array
    xor ecx, ecx

.pml2:
    cmp qword [r9 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml2_next

    push rcx
    
    mov r8, qword [r9 + rcx * STATIC_PTR_SIZE_byte]
    or r8, qword [kernel_page_mirror]
    and r8, STATIC_PAGE_mask

    xor ecx, ecx

.pml1:
    cmp qword [r8 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml1_next

    test word [r8 + rcx * STATIC_PTR_SIZE_byte], KERNEL_PAGE_FLAG_process
    jz .pml1_next

    ; release page from array
    mov rdi, qword [r8 + rcx * STATIC_PTR_SIZE_byte]
    and rdi, STATIC_PAGE_mask
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release_page

.pml1_next:
    inc cx

    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml1

    pop rcx
    
    test word [r9 + rcx * STATIC_PTR_SIZE_byte], KERNEL_PAGE_FLAG_process
    jz .pml2_next

    mov rdi, qword [r9 + rcx * STATIC_PTR_SIZE_byte]
    and di, STATIC_PAGE_mask
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release_page

.pml2_next:
    inc cx
    
    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml2

    pop rcx
    
    ; PML2 belongs to processing
    test word [r10 + rcx * STATIC_PTR_SIZE_byte], KERNEL_PAGE_FLAG_process
    jz .pml3_next

    mov rdi, qword [r10 + rcx * STATIC_PTR_byte]
    and di, STATIC_PAGE_mask
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release_page

.pml3_next:
    inc cx
    
    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml3

    pop rcx

    test word [r11 + rcx * STATIC_PTR_SIZE_byte], KERNEL_PAGE_FLAG_process
    jz .pml4_next

    mov rdi, qword [r11 + rcx * STATIC_PTR_SIZE_byte]
    and di, STATIC_PAGE_mask
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release_page

.pml4_next:
    inc cx
    
    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml4
    
    mov rdi, r11
    and di, STATIC_PAGE_mask
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release_page

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rcx

    ret

kernel_page_extend:
    push rdi

    ; next entry number
    inc r13
    
    cmp r13, KERNEL_PAGE_ENTRY_count
    je .pml3

    cmp qword [r9 + r13 * STATIC_QWORD_SIZE_byte], EMPTY
    jne .pml2_entry

    ; assign page for PML2 entry
    call kernel_memory_alloc_page
    jc .end

    or di, bx
    mov qword [r9 + r13 * STATIC_QWORD_SIZE_byte], rdi

.pml2_entry:
    ; retrieve PML1 array address from PML2 array
    mov r8, qword [r9 + r13 * STATIC_QWORD_SIZE_byte]
    or r8, qword [kernel_page_mirror]
    and r8, STATIC_PAGE_mask

    xor r12, r12
    
    jmp .end

.pml3:
    inc r14
    
    cmp r14, KERNEL_PAGE_ENTRY_count
    je .pml4

    cmp qword [r10 + r14 * STATIC_QWORD_SIZE_byte], EMPTY
    jne .pml3_entry

    ; assign page for PML3 entry
    call kernel_memory_alloc_page
    jc .end

    ; store PML2 array address inside PML3 entry
    
    ; apply flags
    or di, bx
    mov qword [r10 + r14 * STATIC_QWORD_SIZE_byte], rdi

.pml3_entry:
    ; retrieve PML2 array address from PML3 entry
    mov r9, qword [r10 + r14 * STATIC_QWORD_SIZE_byte]
    or r9, qword [kernel_page_mirror]
    and r9, STATIC_PAGE_mask

    xor r13, r13

    jmp .pml2_entry
    
.pml4:
    inc r15

    cmp r15, KERNEL_PAGE_ENTRY_count
    je .error

    cmp qword [r11 + r15 * STATIC_QWORD_SIZE_byte], EMPTY
    jne .pml4_entry

    call kernel_memory_alloc_page
    jc .end

    or di, bx
    mov qword [r11 + r15 * STATIC_QWORD_SIZE_byte], rdi


.pml4_entry:
    ; retrieve PML3 array address from PML4 entry
    mov r10, qword [r11 + r15 * STATIC_QWORD_SIZE_byte]
    or r10, qword [kernel_page_mirror]
    and r10, STATIC_PAGE_mask

    ; first entry number of PML1 array
    xor r14, r14

    ; new PML3 assigned
    jmp .pml3_entry

.end:
    pop rdi
    ret

.error:
    mov rsi, kernel_log_page
    call driver_serial_string
    
    jmp $


kernel_page_map:
    push rcx
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    ; prepare default paging structure
    call kernel_page_prepare
    jc .end

    or si, bx

.next:
    cmp r12, KERNEL_PAGE_ENTRY_count
    jb .entry

    ; extend paging array
    call kernel_page_extend
    jc .end

.entry:
    ; store phyical source address with corresponding flags
    mov qword [r8 + r12 * STATIC_QWORD_SIZE_byte], rsi
    
    ; next part of space
    add rsi, STATIC_PAGE_SIZE_byte

    ; next entry from PML1 array
    inc r12

    dec rcx
    jnz .next

.end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rcx

    ret

kernel_page_merge:
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; conert process paging array pointer to high half
    or r11, qword [kernel_page_mirror]

    ; first kernel entry in PML4 array
    mov ecx, KERNEL_PAGE_ENTRY_count >> STATIC_DIVIDE_BY_2_shift

    mov r15, qword [kernel_environment_base_address]
    mov r15, qword [r15 + KERNEL_STRUCTURE.page_base_address]

.pml4:
    cmp qword [r15 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml4_next

    ; process entry
    cmp qword [r11 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml4_next

    cmp qword [r11 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml4_map

    ; preserve original registser
    push rax


    ; kernel PML3 array
    mov r14, qword [r15 + rcx * STATIC_PTR_SIZE_byte]
    and r14, STATIC_PAGE_mask
    or r14, qword [kernel_page_mirror]

    mov r10, qword [r11 + rcx * STATIC_PTR_SIZE_byte]
    and r10, STATIC_PAGE_mask
    or r10, qword [kernel_page_mirror]

    ; first kernel entry PML3 array
    xor ecx, ecx

.pml3:
    cmp qword [r14 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml3_next

    cmp qword [r10 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml3_mp

    ; preserve original register 
    push rcx

    mov r13, qword [r14 + rcx * STATIC_PTR_SIZE_byte]
    and r13, STATIC_PAGE_mask
    or r13, qword [kernel_page_mirror]
    
    mov r9, qword [r10 + rcx * STATIC_PTR_SIZE_byte]
    and r9, STATIC_PAGE_mask
    or r9, qword [kernel_page_mirror]

    xor ecx, ecx

.pml2:
    cmp qword [r13 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml2_next

    cmp qword [r9 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml2_map

    push rcx

    mov r12, qword [r13 + rcx * STATIC_PTR_SIZE_byte]
    and r12, STATIC_PAGE_mask
    or r12, qword [kernel_page_mirror]

    mov r8, qword [r9 + rcx * STATIC_PTR_SIZE_byte]
    and r8, STATIC_PAGE_mask
    or r8, qword [kernel_page_mirror]

    xor ecx, ecx

.pml1:
    cmp qword [r12 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    je .pml1_next
    
    cmp qword [r8 + rcx * STATIC_PTR_SIZE_byte], EMPTY
    jne .pml1_next

    ; mapping to process
    push qword [r12 + rcx * STATIC_PTR_SIZE_byte]
    pop qword [r8 + rcx * STATIC_PTR_SIZE_byte]

.pml1_next:
    inc cx

    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml1

    pop rcx

    ; next entry
    jmp .pml2_next

.pml2_map:
    ; map to process
    push qword [r13 + rcx * STATIC_PTR_SIZE_byte]
    pop qword [r9 + rcx * STATIC_PTR_SIZE_byte]

.pml2_next:
    ; next
    inc cx

    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml2

    ; restore original register
    pop rcx

    jmp .pml3_next

.pml3_map:
    push qword [r14 + rcx * STATIC_PTR_SIZE_byte]
    pop qword [r10 + rcx * STATIC_PTR_SIZE_byte]

.pml3_next:
    inc cx

    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml3
    
    ; restore original register
    pop rcx

    ; next entry
    jmp .pml4_next

.pml4_next:
    inc cx

    cmp cx, KERNEL_PAGE_ENTRY_count
    jb .pml4

    pop r15
    pop r14
    pop r13
    pop r12
    pop r10
    pop r9
    pop r8
    pop rcx

    ret

kernel_page_prepare:
    push rax
    push rcx
    push rdx
    push rdi

    mov rdx, ~KERNEL_PAGE_mask
    and rax, rdx

    ; compute entry number of PML4 array

    ; higher of address part is not involved
    ; in calculation
    xor edx, edx
    mov rcx, KERNEL_PAGE_PML3_SIZE_byte
    div rcx

    ; store PML4 entry number
    mov r15, rax

    or r11, qword [kernel_page_mirror]
    cmp qword [r11 + rax * STATIC_QWORD_SIZE_byte], EMPTY
    jne .pml3

    ; assing page for r15 entry
    call kernel_memory_alloc_page
    jc .end

    mov qword [r11 + rax, STATIC_QWORD_SIZE_byte], rdi
    or word [r11 + rax * STATIC_QWORD_SIZE_byte], bx

.pml3:
    ; retrieve PML3 array address from PML4 entry
    mov r10, qword [r11 + rax * STATIC_QWORD_SIZE_byte]
    and r10, STATIC_PAGE_mask

    ; compute entry number of PML3 array
    ; restore rest of division
    mov rax, rdx
    mov rcx, KERNEL_PAGE_PML2_SIZE_byte
    xor edx, edx
    div rcx

    mov r14, rax

    or r10, qword [kernel_page_mirror]
    cmp qword [r10 + rax * STATIC_QWORD_SIZE_byte], EMPTY
    jne .pml2

    ; assign page for r14 entry
    call kernel_memory_alloc_page
    jc .end

    mov qword [r10 + rax * STATIC_QWORD_SIZE_byte], rdi
    or word [r10 + rax * STATIC_QWORD_SIZE_byte], bx

.pml2:
    ; retrieve PML2 array address from PML3 entry
    mov r9, qword [r10 + rax * STATIC_QWORD_SIZE_byte]
    and r9, STATIC_PAGE_mask

    ; compute entry number of PML2 array

    ; restore rest of division
    mov rax, rdx
    mov rcx, KERNEL_PAGE_PML1_SIZE_byte
    ; higher of address part if not involved in calculations
    xor edx, edx
    div rcx

    ; restore PML2 entry number
    mov r13, rax

    or r9, qword [kernel_page_mirror]
    cmp qword [r9 + rax * STATIC_QWORD_SIZE_byte], EMPTY
    jne .pml1

    ; assign page for R13 entry
    call kernel_memory_alloc_page
    jc .end

    ; store PML1 address inside PML2 entry
    mov qword [r9 + rax * STATIC_QWORD_SIZE_byte], rdi
    or word [r9 + rax * STATIC_QWORD_SIZE_byte], bx

.pml1:
    ; retrieve PML1 array address from PML2 entry
    mov r8, qword [r9 + rax * STATIC_QWORD_SIZE_byte]
    ; convert to logical address
    or r8, qword [kernel_page_mirror]
    ; drop flags
    and r8, STATIC_PAGE_mask

    ; compute entry number of PML1 array

    ; restore rest of division
    mov rax, rdx
    mov rcx, STATIC_PAGE_SIZE_byte
    ; higher of address part is not involved in calculations
    xor edx, edx
    div rcx

    ; restore PML1 entry number
    mov r12, rax

.end:
    pop rdi
    pop rdx
    pop rcx
    pop rax

    ret

kernel_page_release:
    push rax
    push rdx
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rcx

    mov rdx, ~KERNEL_PAGE_mask
    and rax, rdx

    ; compute entry number PML4 array

    ; higher of address part is not involved in
    ; calculations
    xor edx, edx
    mov rcx, KERNEL_PAGE_PML3_SIZE_byte
    div rcx

    ; store PML4 entry number
    mov r15, rax

    ; convert pointer of PML4 to logical
    or r11, qword [kernel_page_mirror]

    ; retrieve PML3 array address from PML4 entry
    mov r10, qword [r11 + rax * STATIC_QWORD_SIZE_byte]
    ; drop flags
    and r10, STATIC_PAGE_mask

    ; compute entry number of PML3 array
    ; restore rest of division
    mov rax, rdx
    mov rcx, KERNEL_PAGE_PML2_SIZE_byte
    ; higher of address part is not involved in
    ; calculations
    xor edx, edx
    div rcx

    ; store PML3 entry number
    mov r14, rax

    ; convert pointer of PML3 to logcal
    or r10, qword [kernel_page_mirror]

    ; retrieve PML2 array addres from PML3 entry
    mov r9, qword [r10 + rax * STATIC_QWORD_SIZE_byte]
    and r9, STATIC_PAGE_mask

    ; compute entry number of PML2 array

    ; restore rest of division
    mov rax, rdx
    mov rcx, KERNEL_PAGE_PML1_SIZE_byte
    ; higher of address part is not involved in
    ; calculations
    xor edx, edx
    div rcx

    mov r13, rax

    ; convert pointer of PML2 to logical
    or r9, qword [kernel_page_mirror]

    ; retrieve PML1 array address from PML2 entry
    mov r9, qword [r9 + rax * STATIC_QWORD_SIZE_byte]
    ; drop flags
    and r8, STATIC_PAGE_mask

    ; compute entry number of PML1 array

    ; restore rest of division
    mov rax, rdx
    mov rcx, STATIC_PAGE_SIZE_byte
    ; higher of address part if not involved in
    ; calculations
    xor edx, edx
    div rcx

    mov r12, rax

    or r8, qword [kernel_page_mirror]

    ; space size in pages
    mov rcx, qword [rsp]

.pml1:
    ; prepare page for release
    xor edi, edi
    xchg rdi, qword [r8 + r12 * STATIC_QWORD_SIZE_byte]

    test rdi, rdi
    jz .not

    ; release page

    ; drop flags
    and di, STATIC_PAGE_mask
    ; convert page address to logical
    or rdi, qword [kernel_page_mirror]
    call kernel_memory_release_page

.no:
    ; page from space, release
    dec rcx
    ; whole space released
    jz .end

    inc r12

    ; end of PML1 array
    cmp r12, KERNEL_PAGE_ENTRY_count
    jb .pml1

.pml2:
    inc r13

    cmp r13, KERNEL_PAGE_ENTRY_count
    je .pml3

.pml2_countinue:
    cmp qword [r9 + r13 * STATIC_QWORD_SIZE_byte], EMPTY
    je .pml2_empty

    mov r8, qword [r9 + r13 * STATIC_QWORD_SIZE_byte]

    ; drop flags and convert to logical address
    and r8w, STATIC_PAGE_mask
    or r8, qword [kernel_page_mirror]

    ; start from first entry
    xor r12, r12

    jmp .pml1

.pml2_empty:
    ; forced release
    sub rcx, KERNEL_PAGE_ENTRY_count
    jz .end
    js .end

    jmp .pml2

.pml3:
    inc r14
    cmp r14, KERNEL_PAGE_ENTRY_count
    je .pml4

.pml3_continue:
    cmp qword [r10 + r14 * STATIC_QWORD_SIZE_byte], EMPTY
    je .pml3_empty
    
    ; retrieve PML2 address
    mov r9, qword [r10 + r14 * STATIC_QWORD_SIZE_byte]

    ; drop flags and convert to logical address
    and r9w, STATIC_PAGE_mask
    or r9, qword [kernel_page_mirror]

    ; start from first entry
    xor r13, r13

    jmp .pml2_continue

.pml3_empty:
    ; forced release
    sub rcx, KERNEL_PAGE_ENTRY_count * KERNEL_PAGE_ENTRY_count
    jz .end
    js .end

    jmp .pml3

.pml4:
    ; next entry of PML4
    inc r15

    ; end of PML4
    cmp r15, KERNEL_PAGE_ENTRY_count
    je .pml5

    cmp qword [r11 + r15 * STATIC_QWORD_SIZE_byte], EMPTY
    je .pml4_empty

    ; retrieve PML3 address
    mov r10, qword [r11 + r15 * STATIC_QWORD_SIZE_byte]

    ; drop flags and convert to logical address
    and r10w, STATIC_PAGE_mask
    or r10, qword [kernel_page_mirror]

    ; start from first entry
    xor r14, r14

    ; continue with PML3
    jmp .pml3_continue


.pml4_empty:
    sub rcx, KERNEL_PAGE_ENTRY_count * KERNEL_PAGE_ENTRY_count * KERNEL_PAGE_ENTRY_count
    jz .end
    js .end

    jmp .pml4


.pml5:
    jmp $

.end:
    pop rcx
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rax

    ret