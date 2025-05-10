.intel_syntax noprefix

/*
// 0x20 bytes
typedef struct header {
    char *field_name; // Host, Content-Length, etc.
    char *field_contents;   // 192.168.30.12, 12, etc.
    header *next_header;
    char padding[8];
} header;
*/


/*
// 0x30 bytes
typedef struct http_req {
    char *req_verb; // GET, POST, etc.
    char *url;
    char *version;
    header *headers; // Host, Content-Length, etc.
    char *body;
    size_t body_len;
} http_req;
*/

/*
char *hr_url(struct http_req *hr);
*/
.global hr_verb
hr_verb:
    push rbp
    mov rbp, rsp

    mov rax, [rdi]

    mov rsp, rbp
    pop rbp
    ret

.global hr_url
hr_url:
    push rbp
    mov rbp, rsp

    mov rax, [rdi + 8]

    mov rsp, rbp
    pop rbp
    ret

.global hr_body_len
hr_body_len:
    push rbp
    mov rbp, rsp

    mov rax, [rdi + 40]

    mov rsp, rbp
    pop rbp
    ret

.global hr_body
hr_body:
    push rbp
    mov rbp, rsp

    mov rax, [rdi + 32]

    mov rsp, rbp
    pop rbp
    ret
