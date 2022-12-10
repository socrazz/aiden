lib_elf_check:
    cmp dword [rdi + LIB_ELF_STRUCTURE.magic_number], 0x464C457F
    jne .error

    clc
    jmp end

.error:
    stc

.end:
    ret