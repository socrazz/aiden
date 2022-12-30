%define KERNEL_name "aiden"
%define KERNEL_version "0"
%define KERNEL_revision "1468"
%define KERNEL_architecture "x86_64"
%define KERNEL_language "Assembly"

%define KERNEL_BASE_location 0xFFFFFFFF80000000

struc KERNEL_STRUCTURE
    ; variable of SMP management function
    .cpu_count resq 1

    ; variable of PS2 controller management functions
    .driver_ps2_mouse_x resw 1
    .driver_ps2_mouse_y resw 1
    .driver_ps2_mouse_statu resb 1

    ; align to the next label
    alignb 0x04

    ; variable of framebuffer management function
    .framebuffer_base_address resq 1
    .framebuffer_width_pixel resw 1

    ; align net label
    alignb 0x08

    .framebuffer_height_pixel resw 1

    ; align to the next label
    alignb 0x08

    .framebuffer_pid resq 1

    ; variables of I/O APIC management function
    .io_apic_base_address resq 1

    ; variables of library management functin
    .library_base_addres resq 1
    .library_memory_map_address resq 1

    ; variables of memory management function
    .memory_base_address resq 1
    .memory_semaphore resb 1

    ; align to the next label
    alignb 0x08

    ; variables of page management functions
    .page_base_address resq 1
    .page_total resq 1
    .page_available resq 1
    .page_limit resq 1

    ; variables of storage management functions
    .storage_base_address resq 1
    .storage_root_id resb 1

    ; align to the next label
    alignb 0x08

    ; variables of task manamgement functions
    .task_queue_address resq 1
    .task_ap_address resq 1
    .task_id resq 1
    .task_count resq 1
    .task_queue_semaphore resb 1

    ; align to the next label
    alignb 0x08

    .SIZE:
endstruc