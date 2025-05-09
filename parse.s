.intel_syntax noprefix


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

    /* Save http_req struct pointer */
    mov r8, rdi
    mov r9, rdx

    /* allocate saveptr */
    sub rsp, 0x10

    xor r10, r10

verb_and_url: /* Parse verb and url */
    mov rdi, rsi    /* inbuf */
    mov rsi, r9     /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x20   /* space */
    call parse_token

    mov [r8 + r10*8], rax /* Save token */

    inc r10
    cmp r10, 2
    jb verb_and_url

    mov rdi, rsi    /* inbuf */
    mov rsi, r9     /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x0a   /* newline */
    call parse_token

    mov rdi, rax
    call strip_ws   /* remove carriage return */

    mov [r8 + r10*8], rax /* Save token */

parse_headers:
    /* parse field name */
    mov rdi, rsi    /* inbuf */
    mov rsi, r9     /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x3a   /* colon */
    call parse_token

    /* TODO: Store field name */

    /* parse field contents */
    mov rdi, rsi    /* inbuf */
    mov rsi, r9     /* inbuf_len */
    mov rdx, rsp    /* saveptr */
    mov rcx, 0x0a   /* newline */
    call parse_token

    mov rdi, rax
    call strip_ws   /* remove carriage return */

    /* TODO: Store field contents */

    /* Check if headers end */
    mov rax, [rsp]
    inc rax
    cmp [rax], 0x0d /* carriage return */
    je parse_content

    jmp parse_headers

parse_content: /* TODO implement this */
/*
    add [rsp], 3 /* set saveptr to after '\r\n' header conclusion
parse_body:
*/

    mov rax, r8

exit_parse_request:
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
