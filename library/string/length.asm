%include "default.inc"

lib_string_length:
    push rsi

    ; emptry string as default
    mov rcx, STATIC_MAX_unsigned

.next:
    ; length of current string
    inc rcx
    ; consider to the next byte
    inc rsi

    cmp byte [rsi - 1], STATIC_ASCII_TERMINATOR
    jne .next

.end:
    pop rsi

    ret