; global
%include "default.inc"
; lib
%include "library/elf.inc"
%include "library/pkg.inc"
%include "library/sys.inc"
; driver
%include "kernel/driver/ps2.inc"
%include "kernel/driver/serial.inc"
; kernel
%include "kernel/config.inc"
%include "kernel/exec.inc"
%include "kernel/gdt.inc"
%include "kernel/idt.inc"
%include "kernel/io_apic.inc"
%include "kernel/lapic.inc"
%include "kernel/page.inc"
%include "kernel/storage.inc"
%include "kernel/task.inc"
; kernel environment initialization routines
%include "kernel/init/acpi.inc"
%include "kernel/init/ap.inc"
%include "kernel/init/limine.inc"

; 64 bit code
[bits 64]

default rel

; initialization procedure of kernel environment
global init

; information for linker
section .data
    ; variable, and constant
    %include "kernel/data.asm"
    %include "kernel/init/data.asm"

; information more about linker
section .text
    ; including libraries
    %include "library/pkg.asm"
    %include "library/elf.asm"
    %include "library/string/compare.asm"

    ; driver
    %include "kernel/driver/ps2.asm"
    %include "kernel/driver/serial.asm"
    
    ; kernel env
    %include "kernel/exec.asm"
    %include "kernel/idt.asm"


init:
    ; configure failover output
    call driver_serial_string
    
    ; show kernel name, version, architecture and build time
    mov rsi, kernel_log_welcome
    call driver_serial_string
    
    ; create binary memory map
    call kernel_init_memory

    ; store information about framebuffer properties
    call kernel_init_framebuffer

    ; parse ACPI tables
    call kernel_init_acpi

    call kernel_init_page
    