COMPILER = gcc
CCFLAGS = -g -Wall
YACC = bison
LEX = flex
YYFLAGS = -y -d
LEXFLAGS = -I
all: psh

y.tab.o lex.yy.o: y.tab.c lex.yy.c
	$(COMPILER) $(CCFLAGS) -c y.tab.c lex.yy.c

varlist.o: varlist.c
	$(COMPILER) $(CCFLAGS) -c -o varlist.o varlist.c

psh: y.tab.o lex.yy.o varlist.o
	$(COMPILER) $(CCFLAGS) y.tab.o lex.yy.o varlist.o -o psh

y.tab.c y.tab.h: psh.y
	$(YACC) $(YYFLAGS) psh.y

lex.yy.c: psh.l
	$(LEX) $(LEXFLAGS) psh.l

clean:
	rm -rf psh varlist.o lex.yy.c lex.yy.o y.tab.c y.tab.h y.tab.o

