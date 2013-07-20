%{ 

/*
 * 	psh.l - lexer for Pipe Shell
 *	By Elijah Montgomery
 *
 *	Defines a lexer, compilable with GNU flex or AT&T lex which lexically analyzes
 *	text and returns tokens for The Pipe Shell
 */

#include <stdlib.h> 
#include <string.h> 
#include "psh.h" 
#include "y.tab.h"

void yyerror(char *); 

%} 

%option yylineno 
%option noyywrap 
%option nounput
%option noinput

%% 

"%".*("\n") 		{
				return COMMENT;		
			}
$[a-zA-Z][a-zA-Z]* 	{
				char* newString = malloc(strlen(yytext));
                                memcpy(newString, &yytext[1], strlen(yytext)-1); /* strip '$' */
                                newString[strlen(yytext)-1] = '\0';
				yylval.stringValue = newString;
				return VARIABLE;
			}
\".*\" 			{
                                char * newString = malloc(strlen(yytext) - 1);
                                memcpy(newString, &yytext[1],strlen(yytext) - 2);
                                newString[strlen(yytext)-2] = '\0';
                                yylval.stringValue = newString;
                                return STRING;
                        }
"\n" 			{
                                return EOL;
                        }
"setprompt" 		{
                                return SETPROMPT;
                        }
"setvar" 		{
                                return SETVAR;
                        }
"echocmd" 		{
                                return ECHOCMD;
                        }
"parsecmd" 		{
                                return PARSECMD;
                        }
"showchild" 		{
                                return SHOWCHILD;
                        }
"cd" 			{
                                return CD;
                        }
"exit" 			{
                                return EXIT;
                        }
("<"|">"|"|"|"&") 	{
				return *yytext;
                        }
[ \t]+ 			{
				; /* ignore whitespace except if caught in strings earlier*/
			}
						
("!"|"@"|"#"|"$"|"%"|"^"|"*"|"("|")"|"-"|"_"|"+"|"="|"{"|"}"|"["|"]"|"\\"|"\'"|":"|";"|"\/"|"."|","|"~"|"`"|[a-zA-Z0-9])+ {
                                yylval.stringValue = strdup(yytext);
                                return WORD; /* Has to be last, else above tokens could match for word. We want everything that doesn't match above to fall through(I think) */
                        }
%%
