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
handle_conn:
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
        lea rdi, [rbp - 0x100]    /* inbuf */
        mov rsi, r14            /* inbuf len */
        lea rdx, [rbp - 0x110]    /* saveptr */
        call parse_token

        /* Token 2 (file path) */
        mov rdi, 0x00           /* inbuf */
        mov rsi, r14            /* inbuf len */
        lea rdx, [rbp - 0x110]  /* saveptr */
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

        add rsp, 0x200

        /* Close clientfd in child */
        mov rdi, r13
        mov rax, 3
        syscall

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

/*
Parses next token in given text buffer up to the specified delimiter.

char * parse_token(char *inbuf,
                   size_t inbuf_len,
                   char **saveptr,
                   char delim);


RETURN
- Returns pointer to start of first token found or NULL if none found.
- Replaces delimiter with null to make the token a C string.

SAVEPTR
- If end of token is found, saves position in *saveptr so that it can continue
        where it left off. Otherwise, sets *saveptr to NULL.
- If *saveptr is non-NULL, continues parsing from that position.
        Otherwise, parse from beginning of inbuf.

SAFETY
- Parsing does not go past inbuf_len.
- Will not read past NULL terminators.
- If a token continues past inbuf_len, the token will include all
        remaining bytes and not be terminated. *saveptr will be set to
        NULL.
*/
parse_token:
        push rbp
        mov rbp, rsp

        xor r8, r8

        /* Load saveptr if non-NULL */
        cmp QWORD PTR [rdx], 0
        je find_start
        mov rdi, [rdx]

find_start: /* Find token start index */
        cmp r8, rsi
        jae no_token /* No token found before end of inbuf */

        cmp BYTE PTR [rdi + r8], 0 /* NULL */
        je no_token /* no token found before end of str */

        cmp BYTE PTR [rdi + r8], cl /* delim */
        jne start_found

        inc r8
        jmp find_start

start_found: /* Start of token found */
        lea rax, [rdi + r8] /* Save start in rax */

find_end: /* Scan to end of token */
        cmp r8, rsi
        /* Assume str ends with '\0' so it doesnt need to be set */
        jae no_end

        mov r9b, [rdi + r8]
        test r9b, r9b   /* NULL check */
        jz parse_done
        cmp r9b, cl     /* delim check */
        je parse_done

        inc r8
        jmp find_end

parse_done:
        /* Add NULL terminator */
        mov BYTE PTR [rdi + r8], 0

        /* Save where left off */
        lea r9, [rdi + r8 + 1]
        mov [rdx], r9

        jmp exit_parse_token

no_token:
        mov rax, 0
no_end:
        mov QWORD PTR [rdx], 0
exit_parse_token:
        mov rsp, rbp
        pop rbp
        ret

/*
Expects null-terminated string and will replace first newline found with
'\0'.
params: rdi(ptr) inbuf
*/
nullify_newline:
        push rbp
        mov rbp, rsp

        xor rcx, rcx
keep_reading:
        cmp BYTE PTR [rdi + rcx], 0x0a
        je newline_found

        cmp BYTE PTR [rdi + rcx], 0x00
        je newline_not_found

        inc rcx
        jmp keep_reading

newline_found:
        mov BYTE PTR [rdi + rcx], 0x00
newline_not_found:
        mov rsp, rbp
        pop rbp
        ret
