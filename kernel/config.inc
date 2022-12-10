%define KERNEL_name "aiden"
%define KERNEL_version "0.0.1"
%define KERNEL_revision "1461"
%define KERNEL_architecture "x86_64"
%define KERNEL_language "Assembly"

%define KERNEL_BASE_address 0xFFFFFFFF80000000

struc KERNEL_STRUCTURE
    ; variable of smp management function
    .cpu_count resq 1
    ; variable of i/o apic management function
    .io_apic_base_address resq 1
    ; variable of LAPIC management function
    .lapic_base_address resq 1

    .memory_base_address resq 1
    .memory_semaphore resb 1

    alignb 0x08

    ; variables of page management functions
    .page_base_address resq 1
    .page_total resq 1
    .page_available resq 1
    .page_limit resq 1

    ; variables of storage management function
    .storage_base_address resq 1
    .storage_root_id resb 1

    alignb 0x08

    ; variables of task management function
    .task_queue_address resq 1
    .task_ap_address resq 1
    .task_id resq 1
    .task_count resq 1
    .task_queue_semaphore resb 1

    alignb 0x08

    ; length of this structure in bytes
    .SIZE:
endstruc