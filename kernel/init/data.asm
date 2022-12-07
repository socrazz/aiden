kernel_acpi_standard db "RSDT (root system descriptor pointer) found.", STATIC_ASCII_TERMINATOR
kernel_acpi_extended db "XSDT (extended system descriptor table) found.", STATIC_ASCII_TERMINATOR
kernel_acpi_lapic db STATIC_ASCII_NEWLINE, " LAPIC base address 0x", STATIC_ASCII_TERMINATOR
kernel_acpi_io_apic db STATIC_ASCII_NEWLINE, " I/O APIC base address 0x", STATIC_ASCII_TERMINATOR

kernel_log_framebuffer db STATIC_ASCII_NEW_LINE, "static kernel_log_framebuffer", STATIC_ASCII_TERMINATOR
kernel_log_prefix db STATIC_ASCII_NEW_LINE, "+", STATIC_ASCII_TERMINATOR
kernel_log_free db " KiB released." STATIC_ASCII_TERMINATOR
kernel_log_kernel db STATIC_ASCII_NEW_LINE, "just testing log kernel right awkoak", STATIC_ASCII_TERMINATOR
kernel_log_memory db STATIC_ASCII_NEW_LINE, "log kernel here", STATIC_ASCII_TERMINATOR
kernel_log_page db STATIC_ASCII_NEW_LINE "tiga pagi - fletch", STATIC_ASCII_TERMINATOR
kernel_log_rsdp db STATIC_ASCII_NEW_LINE "dalam diam, ada luka yang tertawa riang", STATIC_ASCII_TERMINATOR
kernel_log_smp db " AP initialized", STATIC_ASCII_TERMINATOR
kernel_log_storage db STATIC_ASCII_NEW_LINE, "operation fail succesfully awoaowka", STATIC_ASCII_TERMINATOR
kernel_log_system db STATIC_ASCII_NEW_LINE "System disk [KiB]:", STATIC_ASCII_TERMINATOR
kernel_log_welcome db KERNEL_name, " (build v", KERNEL_version, ".", KERNEL_revision, " ", KERNEL_architecture, " ", KERNEL_language, ", compiled ", __DATE__, " ", __TIME__, ")", STATIC_ASCII_NEW_LINE, STATIC_ASCII_TERMINATOR"

kernel_smp_count dq EMPTY
kernel_exec_file_init db "wm"

align 0x08, db 0x00
kernel_limine_framebuffer_request:
    dq LIMINE_FRAMEBUFFER_MAGIC
    dq 0
    dq EMPTY

align 0x08, db 0x00
kernel_limine_kernel_file_request:
    dq LIMINE_KERNEL_FILE_MAGIC
    dq 0
    dq EMPTY

align 0x08, db 0x00
kernel_limine_kernel_address_request:
    dq LIMINE_KERNEL_ADDRESS_MAGIC
    dq 0
    dq EMPTY

align 0x08, db 0x00
kernel_limine_memmap_request:
    dq LIMINE_MEMMAP_MAGIC
    dq 0
    dq EMPTY

align 0x08, db 0x00
kernel_limine_rsdp_request:
    dq LIMINE_RSDP_MAGIC
    dq 0
    dq EMPTY

align 0x08, db 0x00
kernel_limine_smp_requet:
    dq LIMINE_SMP_MAGIC
    dq 0
    dq EMPTY
    dq EMPTY

align 0x08, db 0x00
kernel_limine_module_request:
    dq LIMINE_MODULE_MAGIC
    dq 0
    dq EMPTY