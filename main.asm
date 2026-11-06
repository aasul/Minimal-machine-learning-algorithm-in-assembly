bits 64
default rel

%ifndef MAX_EPOCHS
%define MAX_EPOCHS 100
%endif
%if MAX_EPOCHS < 1 || MAX_EPOCHS > 10000
%error MAX_EPOCHS must be between 1 and 10000
%endif

%macro say 1
    lea rsi, [%1]
    call puts
%endmacro

section .rodata
data:
    dq 0, 0, 0,  0, 1, 0,  1, 0, 0,  1, 1, 1
    dq 0, 0, 0,  0, 1, 1,  1, 0, 1,  1, 1, 1
    dq 0, 0, 1,  0, 1, 1,  1, 0, 1,  1, 1, 0
    dq 0, 0, 0,  0, 1, 1,  1, 0, 1,  1, 1, 0
names: dq and_name, or_name, nand_name, xor_name
and_name: db 'and', 10, 0
or_name: db 'or', 10, 0
nand_name: db 'nand', 10, 0
xor_name: db 'xor', 10, 0
initial: db 'initial', 0
epoch_text: db 'epoch ', 0
errors_text: db ' errors=', 0
w1_text: db ' w1=', 0
w2_text: db ' w2=', 0
bias_text: db ' bias=', 0
ok_text: db 'converged', 10, 0
fail_text: db 'nonconvergence after ', 0
epochs_text: db ' epochs', 10, 0
space: db ' ', 0
arrow: db ' -> ', 0
want: db ' (want ', 0
close: db ')', 10, 0
nl: db 10, 0
usage: db 'usage: perceptron [xor]', 10
usage_len: equ $ - usage

section .bss
w1: resq 1
w2: resq 1
bias: resq 1
epoch: resq 1
errors: resq 1
buf: resb 32

section .text
global _start

_start:
    lea r12, [data]
    lea r13, [names]
    mov r14d, 3
    cmp qword [rsp], 1
    je .gate
    cmp qword [rsp], 2
    jne .usage
    mov rax, [rsp + 16]
    cmp byte [rax], 'x'
    jne .usage
    cmp byte [rax + 1], 'o'
    jne .usage
    cmp byte [rax + 2], 'r'
    jne .usage
    cmp byte [rax + 3], 0
    jne .usage
    add r12, 3 * 96
    add r13, 3 * 8
    mov r14d, 1
.gate:
    mov rsi, [r13]
    call puts
    mov qword [w1], 0
    mov qword [w2], 0
    mov qword [bias], 0
    mov qword [epoch], 0
    say initial
    call params
    call train
    test eax, eax
    jnz .failed
    say ok_text
    call demo
    say nl
    add r12, 96
    add r13, 8
    dec r14d
    jnz .gate
    xor edi, edi
    jmp exit
.failed:
    say fail_text
    mov rax, [epoch]
    call out
    say epochs_text
    call demo
    mov edi, 1
    jmp exit
.usage:
    mov edi, 2
    lea rsi, [usage]
    mov edx, usage_len
    call write
    mov edi, 2
    jmp exit

train:
.epoch:
    inc qword [epoch]
    mov qword [errors], 0
    mov rbx, r12
    lea rbp, [r12 + 96]
.row:
    mov rsi, rbx
    call predict
    mov rdx, [rbx + 16]
    sub rdx, rax
    test rdx, rdx
    jz .next
    inc qword [errors]
    ; Learning rate is 1: w += err * x, bias += err.
    mov rax, [rbx]
    imul rax, rdx
    add [w1], rax
    mov rax, [rbx + 8]
    imul rax, rdx
    add [w2], rax
    add [bias], rdx
.next:
    add rbx, 24
    cmp rbx, rbp
    jne .row
    say epoch_text
    mov rax, [epoch]
    call out
    say errors_text
    mov rax, [errors]
    call out
    call params
    ; A whole pass without updates proves all four rows agree.
    cmp qword [errors], 0
    je .done
    cmp qword [epoch], MAX_EPOCHS
    jb .epoch
    mov eax, 1
    ret
.done:
    xor eax, eax
    ret

; rsi points to the two inputs; eax returns 0 or 1.
predict:
    mov rax, [rsi]
    imul rax, [w1]
    mov rdx, [rsi + 8]
    imul rdx, [w2]
    add rax, rdx
    add rax, [bias]
    cmp rax, 0
    setge al
    movzx eax, al
    ret

demo:
    mov rbx, r12
    lea rbp, [r12 + 96]
.row:
    mov rax, [rbx]
    call out
    say space
    mov rax, [rbx + 8]
    call out
    say arrow
    mov rsi, rbx
    call predict
    call out
    say want
    mov rax, [rbx + 16]
    call out
    say close
    add rbx, 24
    cmp rbx, rbp
    jne .row
    ret

params:
    say w1_text
    mov rax, [w1]
    call out
    say w2_text
    mov rax, [w2]
    call out
    say bias_text
    mov rax, [bias]
    call out
    say nl
    ret

out:
    lea rsi, [buf + 32]
    mov r8, rax
    test rax, rax
    jns .digits
    neg rax
.digits:
    mov edi, 10
.digit:
    xor edx, edx
    div rdi
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz .digit
    test r8, r8
    jns .write
    dec rsi
    mov byte [rsi], '-'
.write:
    lea rdx, [buf + 32]
    sub rdx, rsi
    mov edi, 1
    jmp write

puts:
    xor edx, edx
.len:
    cmp byte [rsi + rdx], 0
    je .write
    inc rdx
    jmp .len
.write:
    mov edi, 1

write:
    mov eax, 1
    syscall
    cmp rax, -4
    je write
    test rax, rax
    jle .failed
    add rsi, rax
    sub rdx, rax
    jnz write
    ret
.failed:
    mov edi, 1
exit:
    mov eax, 60
    syscall

section .note.GNU-stack noalloc noexec nowrite progbits
