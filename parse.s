.intel_syntax noprefix

.section .rodata
CLEN:
    .ascii "Content-Length\0"

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
.section .text
.global parse_token
parse_token:
    push rbp
    mov rbp, rsp

    xor r8, r8

    /* Load saveptr if non-NULL */
    cmp QWORD PTR [rdx], 0
    je skip_delim
    mov rdi, [rdx]

skip_delim: /* Find token start index */
    cmp r8, rsi
    jae no_token /* No token found before end of inbuf */

    cmp BYTE PTR [rdi + r8], 0 /* NULL */
    je no_token /* no token found before end of str */

    cmp BYTE PTR [rdi + r8], cl /* delim */
    jne token_found

    inc r8
    jmp skip_delim

token_found: /* Start of token found */
    lea rax, [rdi + r8] /* Save start in rax */

next_delim: /* Scan to end of token */
    cmp r8, rsi
    /* Assume str ends with '\0' so it doesnt need to be set */
    jae no_end

    mov r9b, [rdi + r8]
    test r9b, r9b   /* NULL check */
    jz parse_done
    cmp r9b, cl     /* delim check */
    je parse_done

    inc r8
    jmp next_delim

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
.global nullify_newline
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

/*
Parses HTTP request and stores contents in a struct.

// 0x20 bytes
typedef struct header {
    char *field_name; // Host, Content-Length, etc.
    char *field_contents;   // 192.168.30.12, 12, etc.
    header *next_header;
    char padding[8];
} header;

// 0x30 bytes
typedef struct http_req {
    char *req_type; // GET, POST, etc.
    char *url;
    char *version;
    header *headers; // Host, Content-Length, etc.
    char *body;
    size_t body_len;
} http_req;

http_req *parse_request(http_req *outbuf,
             char *inbuf,
             size_t inbuf_len);
*/
.global parse_request
parse_request:
    push rbp
    mov rbp, rsp

    push rbx
    push r12
    push r13
    push r14
    push r15

    /* Save args */
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx

    /* allocate saveptr */
    sub rsp, 0x10

    xor r15, r15
verb_and_url: /* Parse verb and url */
    mov rdi, r13     /* inbuf */
    mov rsi, r14    /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x20   /* space */
    call parse_token

    mov [r12 + r15*8], rax /* Save token */

    inc r15
    cmp r15, 2
    jb verb_and_url

    mov rdi, r13     /* inbuf */
    mov rsi, r14    /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x0a   /* newline */
    call parse_token

    mov rdi, rax
    call strip_ws   /* remove carriage return */

    mov [r12 + r15*8], rax /* Save token */

    /* Check if no headers */
    mov rax, [rsp]
    cmp BYTE PTR [rax], 0x0d /* carriage return */
    je store_body

parse_headers:
    /* parse field name */
    mov rdi, r13     /* inbuf */
    mov rsi, r14    /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x3a   /* colon */
    call parse_token

    mov rbx, rax

    /* Check if field is Content-Length */
    mov rdi, rax
    lea rsi, CLEN
    call str_eq

    test rax, rax
    jnz store_content_len

    /* TODO: Store field name (rbx) in struct */

    /* parse field contents */
    mov rdi, r13     /* inbuf */
    mov rsi, r14    /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x0a   /* newline */
    call parse_token

    mov rdi, rax
    call strip_ws   /* remove carriage return */

    /* TODO: Store field contents */

    /* Check if headers end */
    mov rax, [rsp]
    cmp BYTE PTR [rax], 0x0d /* carriage return */
    je store_body

    jmp parse_headers

store_body:  /* TODO implement this */
    add QWORD PTR [rsp], 2 /* move saveptr to start of body (after '\r\n') */
    mov rax, [rsp]
    mov [r12 + 32], rax

exit_parse_request:
    mov rax, r12

    mov rbx, [rbp - 8]
    mov r12, [rbp - 16]
    mov r13, [rbp - 24]
    mov r14, [rbp - 32]
    mov r15, [rbp - 40]

    mov rsp, rbp
    pop rbp
    ret

store_content_len:
    /* parse field contents */
    mov rdi, r13     /* inbuf */
    mov rsi, r14    /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x0a   /* newline */
    call parse_token

    mov rdi, rax
    call strip_ws   /* remove carriage return */

    /* convert field contents to int and then store */
    mov rdi, rax
    call atoi
    mov [r12 + 40], rax

    /* Check if headers end */
    mov rax, [rsp]
    cmp BYTE PTR [rax], 0x0d /* carriage return */
    je store_body

    jmp parse_headers

/*
Convert alphanum to integer. Expects c string
int atoi(char *inbuf);
*/
.global atoi
atoi:
    push rbp
    mov rbp, rsp

    xor rax, rax
    xor rsi, rsi
    /* rdx could get clobbered by mul so unused */
    xor rcx, rcx
parse_anum:
    mov r8, 10
    mul r8
    add rax, rsi

    cmp BYTE PTR [rdi + rcx], 0
    je atoi_exit

    movzx rsi, BYTE PTR [rdi + rcx]
    sub rsi, 48

    inc rcx
    jmp parse_anum

atoi_exit:
    mov rsp, rbp
    pop rbp
    ret

/*
char *strip_ws(char *inbuf);

- Expects C string
- Removes whitespace at the start and end of the buffer if there is
    non-whitespace contained within the buffer

*/
.global strip_ws
strip_ws:
    push rbp
    mov rbp, rsp

    xor rcx, rcx
remove_leading_ws:
    cmp BYTE PTR [rdi + rcx], 0 /* NULL */
    je no_non_ws

    cmp BYTE PTR [rdi + rcx], 0x20 /* space */
    je keep_skipping_ws

    cmp BYTE PTR [rdi + rcx], 0x0a /* newline */
    je keep_skipping_ws

    cmp BYTE PTR [rdi + rcx], 0x0d /* carriage return */
    je keep_skipping_ws

    jmp remove_trailing_ws
keep_skipping_ws:
    inc rcx
    jmp remove_leading_ws

remove_trailing_ws:
    lea rax, [rdi + rcx]
find_null:
    inc rcx
    cmp BYTE PTR [rdi + rcx], 0
    jne find_null

backtrack_ws:
    dec rcx

    cmp BYTE PTR [rdi + rcx], 0x20 /* space */
    je keep_backtracking

    cmp BYTE PTR [rdi + rcx], 0x0a /* newline */
    je keep_backtracking

    cmp BYTE PTR [rdi + rcx], 0x0d /* carriage return */
    je keep_backtracking

    jmp exit_strip_ws
keep_backtracking:
    jmp backtrack_ws

no_non_ws:
    mov rax, 0
exit_strip_ws:
    mov BYTE PTR [rdi + rcx + 1], 0
    mov rsp, rbp
    pop rbp
    ret

/*
Checks equality of C strings.

bool str_eq(char *s1, char *s2);
*/
.global str_eq
str_eq:
    push rbp
    mov rbp, rsp

    xor rcx, rcx
check_char:
    mov al, [rsi + rcx]
    cmp [rdi + rcx], al
    jne str_eq_false

    cmp BYTE PTR [rdi + rcx], 0
    je str_eq_true

    inc rcx
    jmp check_char

str_eq_false:
    mov rax, 0
    jmp str_eq_exit

str_eq_true:
    mov rax, 1
str_eq_exit:
    mov rsp, rbp
    pop rbp
    ret
