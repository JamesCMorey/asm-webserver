all:
	as -g -o main.o main.s
	as -g -o ds.o ds.s
	as -g parse.s -o parse.o
	ld main.o ds.o parse.o -o asdf

test:
	gcc -g -c wrapper.c -o wrapper.o
	as -g test.s -o test.o
	gcc -z noexecstack wrapper.o test.o -o asdf
