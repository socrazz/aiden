%ifndef KERNEL_LIBRARY
    %define KERNEL_LIBRARY_limit 16
    %define KERNEL_LIBRARY_FLAG_active 1 << 0

    struc KERNEL_LIBRARY_STRUCTURE
        .address resq 1
        .dynsym resq 1
        .dynsym_limit resq 1
        .strtab resq 1
        .size_page resw 1
        .flags resw 1
        .length resb 1
        .name resb 255

        alignb 0x08
        
        .SIZE:
    endstruc
%endif