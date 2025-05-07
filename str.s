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
