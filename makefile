all:
	as -g main.s -o main.o
	as -g str.s -o str.o
	ld main.o str.o -o asdf

test:
	gcc -g -c wrapper.c -o wrapper.o
	as -g test.s -o test.o
	gcc -z noexecstack wrapper.o test.o -o asdf
