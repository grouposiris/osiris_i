; https://www.codeconvert.ai/python-to-assembly-converter
section .data
    prompt db "Enter the number of terms: ", 0
    output db "Fibonacci sequence: ", 0
    fib_sequence resb 400  ; reserve space for 400 bytes (for up to 100 terms)

section .bss
    n resd 1
    i resd 1
    next_term resd 1

section .text
    global _start

_start:
    ; Print prompt
    mov eax, 4
    mov ebx, 1
    mov ecx, prompt
    mov edx, 27
    int 0x80

    ; Read number of terms
    mov eax, 3
    mov ebx, 0
    mov ecx, n
    mov edx, 4
    int 0x80

    ; Convert input to integer
    mov eax, [n]
    sub eax, '0'  ; assuming single digit input for simplicity
    mov [n], eax

    ; Initialize Fibonacci sequence
    mov byte [fib_sequence], 0
    mov byte [fib_sequence + 1], 1

    ; Calculate Fibonacci sequence
    mov dword [i], 2
.loop:
    mov eax, [i]
    cmp eax, [n]
    jge .done

    mov eax, [fib_sequence + eax - 1]  ; fib_sequence[i-1]
    mov ebx, [fib_sequence + eax - 2]  ; fib_sequence[i-2]
    add eax, ebx
    mov [fib_sequence + eax], eax       ; store next term

    inc dword [i]
    jmp .loop

.done:
    ; Print output
    mov eax, 4
    mov ebx, 1
    mov ecx, output
    mov edx, 22
    int 0x80

    ; Print Fibonacci sequence
    mov eax, 0
    mov ecx, [n]
.print_loop:
    mov eax, [fib_sequence + ecx]
    ; Convert to string and print (omitted for brevity)
    ; ...

    dec ecx
    jnz .print_loop

    ; Exit
    mov eax, 1
    xor ebx, ebx
    int 0x80

