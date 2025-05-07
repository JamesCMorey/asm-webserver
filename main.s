.intel_syntax noprefix

.section .rodata
OK:
        .ascii "HTTP/1.0 200 OK\r\n\r\n"
OK_LEN:
        .quad OK_LEN - OK

.section .text
.global _start
_start:
        mov rbp, rsp

        call init_listener
        mov r12, rax /* Save listenfd */

listener_loop:
        /* Accept */
        mov rdi, r12
        mov rsi, 0
        mov rdx, 0
        mov rax, 43
        syscall

        mov r13, rax /* Save clientfd */

        /* Fork to handle client */
        mov rax, 57
        syscall

        cmp rax, 0
        je handle_conn

        /* Close clientfd for listener */
        mov rdi, r13
        mov rax, 3
        syscall

        jmp listener_loop
exit: /* implement program exits */
        mov rdi, 0
        mov rax, 60
        syscall

/*
Create, initialize, bind, and make listen a socket--return sockfd in rax.
*/
init_listener:
        push rbp
        mov rbp, rsp

        /* Create socket */
        mov rdi, 2 /* AF_INET */
        mov rsi, 1 /* SOCK_STREAM */
        mov rdx, 0 /* IPPROTO_IP --> IPPROTO_TCP */
        mov rax, 41
        syscall

        mov r9, rax /* save sockfd */

        add rsp, 0x10

        /* Construct sockaddr_in */
        sub rsp, 16                             /* allocate 16 bytes on stack */
        mov BYTE PTR [rbp - 0x10], 0x02         /* AF_INET */
        mov BYTE PTR [rbp - 0x0f], 0x00
        mov BYTE PTR [rbp - 0x0e], 0x08        /* port 80 */
        mov BYTE PTR [rbp - 0x0d], 0x00
        mov DWORD PTR [rbp - 0x0c], 0x00        /* 0.0.0.0 */
        mov QWORD PTR [rbp - 0x08], 0x00        /* padding */

        /* Bind socket */
        mov rdi, r9
        lea rsi, [rbp - 0x10]
        mov rdx, 16
        mov rax, 49
        syscall

        /* Listen */
        mov rdi, r9
        mov rsi, 0x00
        mov rax, 50
        syscall

        /* Return listening socket */
        mov rax, r9

        mov rsp, rbp
        pop rbp
        ret

handle_conn:
        push rbp
        mov rbp, rsp

        /* Close listenfd in child */
        mov rdi, r12
        mov rax, 3
        syscall

        /* Read request */
        sub rsp, 0x110
        mov rdi, r13
        lea rsi, [rbp - 0x100]
        mov rdx, 0x100
        mov rax, 0
        syscall

        mov r14, rax /* save inbuf len */

        /* Token 1 */
        lea rdi, [rbp - 0x100]  /* inbuf */
        mov rsi, r14            /* inbuf len */
        lea rdx, [rbp - 0x110]  /* saveptr */
        mov rcx, 0x20            /* space */
        call parse_token

        /* Token 2 (file path) */
        mov rdi, 0x00           /* inbuf */
        mov rsi, r14            /* inbuf len */
        lea rdx, [rbp - 0x110]  /* saveptr */
        mov rcx, 0x20            /* space */
        call parse_token

        /* Store file path (dont need inbuf length anymore) */
        mov r14, rax

        mov rdi, r14
        call nullify_newline /* Only really needed for testing */

        /* Open file */
        mov rdi, r14
        mov rsi, 0
        mov rdx, 0
        mov rax, 2
        syscall

        /* Save open fd (filename no longer needed) */
        mov r14, rax

        /* Read contents to memory */
        mov rdi, r14

        sub rsp, 0x200
        mov rsi, rsp

        mov rdx, 0x200
        mov rax, 0
        syscall

        mov r15, rax

        /* Close open file */
        mov rdi, r14
        mov rax, 3
        syscall

        /* Static response (msg header) */
        mov rdi, r13
        lea rsi, OK
        mov rdx, [OK_LEN]
        mov rax, 1
        syscall

        /* Send contents (msb body) */
        mov rdi, r13
        mov rsi, rsp
        mov rdx, r15
        mov rax, 1
        syscall

        /* Close clientfd in child */
        mov rdi, r13
        mov rax, 3
        syscall

        mov rsp, rbp
        pop rbp
        ret

/*
Takes in a pointer to the HTTP GET request alongside its length and stores the url path in fname buffer (outbuf_len >= inbuf_len)
params: rdi(ptr) outbuf, rsi(ptr) inbuf, rdx(int) inbuf_len
*/
parse_request:
        push rbp
        mov rbp, rsp


        mov rsp, rbp
        pop rbp
        ret
