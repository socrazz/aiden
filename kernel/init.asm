; structures, definitions
; global
%include	"default.inc"
; library
%include	"library/elf.inc"
%include	"library/pkg.inc"
%include	"library/sys.inc"
; driver
%include	"kernel/driver/ps2.inc"
%include	"kernel/driver/rtc.inc"
%include	"kernel/driver/serial.inc"
; kernel
%include	"kernel/config.inc"
%include	"kernel/exec.inc"
%include	"kernel/gdt.inc"
%include	"kernel/idt.inc"
%include	"kernel/io_apic.inc"
%include	"kernel/ipc.inc"
%include	"kernel/lapic.inc"
%include	"kernel/library.inc"
%include	"kernel/page.inc"
%include	"kernel/storage.inc"
%include	"kernel/task.inc"
; kernel environment initialization routines
%include	"kernel/init/acpi.inc"
%include	"kernel/init/ap.inc"
%include	"kernel/init/limine.inc"

; 64 bit code
[bits 64]

; we are using Position Independed Code
default	rel

; main initialization procedure of kernel environment
global	init

; information for linker
section	.data
	; variables, constants
	%include	"kernel/data.asm"
	%include	"kernel/init/data.asm"

; information for linker
section .text
	; routines

	; library
	%include	"library/pkg.asm"
	%include	"library/elf.asm"
	%include	"library/string/compare.asm"
	%include	"library/string/length.asm"
	; drivers
	%include	"kernel/driver/ps2.asm"
	%include	"kernel/driver/rtc.asm"
	%include	"kernel/driver/serial.asm"
	; kernel
	%include	"kernel/exec.asm"
	%include	"kernel/idt.asm"
	%include	"kernel/io_apic.asm"
	%include	"kernel/lapic.asm"
	%include	"kernel/library.asm"
	%include	"kernel/memory.asm"
	%include	"kernel/page.asm"
	%include	"kernel/service.asm"
	%include	"kernel/storage.asm"
	%include	"kernel/syscall.asm"
	%include	"kernel/task.asm"
	; kernel environment initialization routines
	%include	"kernel/init/acpi.asm"
	%include	"kernel/init/ap.asm"
	%include	"kernel/init/exec.asm"
	%include	"kernel/init/framebuffer.asm"
	%include	"kernel/init/free.asm"
	%include	"kernel/init/gdt.asm"
	%include	"kernel/init/idt.asm"
	%include	"kernel/init/ipc.asm"
	%include	"kernel/init/library.asm"
	%include	"kernel/init/memory.asm"
	%include	"kernel/init/page.asm"
	%include	"kernel/init/smp.asm"
	%include	"kernel/init/storage.asm"
	%include	"kernel/init/task.asm"
; void
init:
	; configure failover output
	call	driver_serial

	; show kernel name, version, architecture and build time
	mov	rsi,	kernel_log_welcome
	call	driver_serial_string

	; create binary memory map
	call	kernel_init_memory

	; store information about framebuffer properties
	call	kernel_init_framebuffer

	; parse ACPI tables
	call	kernel_init_acpi

	; recreate kernel's paging structures
	call	kernel_init_page

	; switch to new kernel paging array
	mov	rax,	~KERNEL_PAGE_mirror	; physical address
	and	rax,	qword [r8 + KERNEL_STRUCTURE.page_base_address]
	mov	cr3,	rax

	; set new stack pointer
	mov	rsp,	KERNEL_TASK_STACK_pointer

	; create Global Descriptor Table
	call	kernel_init_gdt

	; create Interrupt Descriptor Table
	call	kernel_init_idt

	; create Task queue
	call	kernel_init_task

	; configure Real Time Clock
	call	driver_rtc

	; initialize PS2 keyboard/mouse driver
	call	driver_ps2

	; create interprocess communication system
	call	kernel_init_ipc

	; register all available data carriers
	call	kernel_init_storage

	; prepare library subsystem
	call	kernel_init_library

	; execute init process
	call	kernel_init_exec

	; below, initialization functions does not guarantee original registers preservation

	; initialize other CPUs
	jmp	kernel_init_smp