%define KERNEL_LIBRARY_limit 16
%define KERNEL_LIBRARY_FLAG_active 1 << 0

struc KERNEL_LIBRARY_STRUCTURE
    .address resq 1
    .symbol resq 1
    .symbol_limit resq 1
    .string resq 1
    .size_page resw 1
    .flags resw 1
    .length resb 1
    .name resb 256

    alignb 0x08
    
    .SIZE:
endstruc