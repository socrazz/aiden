%include "default.inc"

lib_string_compare:
  push rax
  push rcx
  push rsi
  push rdi

.loop:
  ; load first character from string
  lodsb

  cmp al, byte [rdi]
  jne .error
  
  inc rdi

  dec rcx
  jnz .loop

  ; matching
  clc 
  jmp .end

.error:
  stc

.end:
  pop rdi
  pop rsi
  pop rcx
  pop rax

  ret
