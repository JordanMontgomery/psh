%{
/*
 *	psh.y - YACC/BISON parser for Pipe Shell project
 *	By Elijah Montgomery
 *	
 *	To use: compile the entire project with "make"
 *	from the root project directory
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <errno.h>
#include <fcntl.h>
#include "psh.h"
#include "y.tab.h"
#include "varlist.h"

extern int errno;

/* all suffixed with cmd are builtin commands */
parseNode* cdCmd(parseNode* cdParm);
parseNode* parsecmdCmd(parseNode* status);
parseNode* exitCmd();
parseNode* showchildCmd(parseNode* status);
parseNode* echocmdCmd(parseNode* status);
parseNode* setvarCmd(char* varName, parseNode* valueWordNode);
parseNode* getVarVal(char* varName);
parseNode* makeWordNode(char* word, eOrigWordType origType);
parseNode* setpromptCmd(parseNode* newPrompt);
parseNode* linkWordNodes(parseNode* firstWordNode, parseNode* nextWordNode);
parseNode* background(parseNode* node);
parseNode* redirectOutput(parseNode* node, parseNode* redirectFrom);
parseNode* redirectInput(parseNode* node, parseNode* redirectTo);
parseNode* pipeSubcommands(parseNode* left, parseNode* right);
void checkIfAnyExited();

int yylex(void);
void ex(parseNode* cmd);

void yyerror(char *s);
%}

%union {
	char *stringValue;
	parseNode* nodePtr;
};

%token <stringValue> VARIABLE
%token <stringValue> STRING
%token EOL
%token SETPROMPT
%token SETVAR
%token ECHOCMD
%token PARSECMD
%token SHOWCHILD
%token COMMENT
%token CD
%token EXIT
%token <stringValue> WORD
%token '<'
%token '>'
%token '|'
%token '&'

%type <nodePtr> command builtin shellword outputRedirectedCommand inputRedirectedCommand pipedcommand subcommand

%%

shell:
		shell command	EOL				{ ex($2); checkIfAnyExited(); printf("%s",prompt);	}
	|	shell builtin	EOL				{ ex($2); checkIfAnyExited(); printf("%s",prompt);	}
	|	shell COMMENT					{ checkIfAnyExited(); printf("%s",prompt);		}
	|	shell EOL					{ checkIfAnyExited(); printf("%s",prompt);		}
	|
	;

command:
		outputRedirectedCommand '&'			{ $$ = background($1);		}
	|	outputRedirectedCommand				{ $$ = $1;			}

outputRedirectedCommand:
		inputRedirectedCommand '>' shellword		{ $$ = redirectOutput($1,$3); 	}
	|	inputRedirectedCommand				{ $$ = $1;			}

inputRedirectedCommand:
		pipedcommand '<' shellword			{ $$ = redirectInput($1,$3); 	}
	|	pipedcommand					{ $$ = $1; 			}

pipedcommand:
		subcommand '|' pipedcommand			{ $$ = pipeSubcommands($1,$3); }
	|	subcommand					{ $$ = pipeSubcommands($1,NULL); }

subcommand:
		shellword					{ $$ = 	linkWordNodes($1,NULL);			}
	|	shellword subcommand				{ $$ = linkWordNodes($1,$2);			}
	;
	
builtin:
		PARSECMD shellword				{ $$ = parsecmdCmd($2); 			}
	|	CD shellword					{ $$ = cdCmd($2);				}
	|	SETVAR VARIABLE shellword			{ $$ = setvarCmd($2,$3);			}
	|	SHOWCHILD shellword				{ $$ = showchildCmd($2);			}
	|	SETPROMPT shellword				{ $$ = setpromptCmd($2);			}
	|	ECHOCMD shellword				{ $$ = echocmdCmd($2);				}
	|	EXIT						{ $$ = exitCmd();				}
	;
	
shellword:
		WORD						{ $$ = makeWordNode($1,origWord); 		}
	|	VARIABLE					{ $$ = getVarVal($1);				}
	|	STRING						{ $$ = makeWordNode($1,origString);		}
	;
	
%%

/* set the background_flag on the specified node */
parseNode* background(parseNode* node)
{
	node->background_flag = 1;
	return node;
}

/* check if any background processes have exited uses non-blocking wait3() so it can be called between lines
of user input to reap background processes without hanging. This prints the exited processe's info if showchild
has been turned on */

void checkIfAnyExited()
{
	pid_t bgExited = 1;
	int childStatus;
	while(bgExited > 0) /* keep looping until we reap all exited background processes */
	{
		bgExited = wait3(&childStatus, WNOHANG, NULL);
		if(bgExited > 0 && showchild_flag == 1)
		{
                	if(WIFEXITED(childStatus))
                        	printf("Background process %d exited normally\n",bgExited);
                        else if(WIFSIGNALED(childStatus))
                        	printf("Background process %d ended because of an uncaught signal\n",bgExited);
                        else if(WIFSTOPPED(childStatus))
                        	printf("Background process %d has stopped\n",bgExited);
		}
	}

}

/* set redirectOutput_flag on the specified node and set redirectOutput to the specified string */
parseNode* redirectOutput(parseNode* node, parseNode* redirectFrom)
{
	node->redirectOutput_flag = 1;
	node->redirectOutput = redirectFrom->nodeWord;
	free(redirectFrom);
	return node;
}

/* set redirectInput_flag on the specified node and set redirectInput to the specified string */
parseNode* redirectInput(parseNode* node, parseNode* redirectTo)
{
	node->redirectInput_flag = 1;
	node->redirectInput = redirectTo->nodeWord;
	free(redirectTo);
	return node;
}

/* connect the command on the left to the command on the right by way of a pipe */
/* essentially the beginning of left is connected to the beginning of right */

parseNode* pipeSubcommands(parseNode* left, parseNode* right)
{
	left->nextPiped = right;
	return left;
}

/* returns a node that instructs the shell to execute the builtin cd command */
parseNode* cdCmd(parseNode* cdParm)
{
	/* convert the Word node to a CD node */
	cdParm->next = NULL;
	cdParm->type = cdCmdNode;
	return cdParm;
}

/* returns a node that instructs the shell to turn on the parsecmd option */
parseNode* parsecmdCmd(parseNode* status)
{
	status->next = NULL;
	status->type = parsecmdCmdNode;
	return status;
}

/* returns a node that instructs the shell to exit */
parseNode* exitCmd()
{
	parseNode* ret = malloc(sizeof(parseNode));
	ret->type = exitCmdNode;
	ret->next = NULL;
	return ret;
}

/* returns a node that instructs the shell to turn on the showchild option */
parseNode* showchildCmd(parseNode* status)
{
	status->next = NULL;
	status->type = showchildCmdNode;
	return status;
}

/* returns a node that tells the shell to turn on the echocmd option */
parseNode* echocmdCmd(parseNode* status)
{
	status->next = NULL;
	status->type = echocmdCmdNode;
	return status;
}

/* returns a node that sets variable $varName to valueWordNode->nodeWord */ 
parseNode* setvarCmd(char* varName, parseNode* valueWordNode)
{
	parseNode* ret = malloc(sizeof(parseNode));
	ret->type = setvarCmdNode;
	ret->nodeVariable = varName;
	ret->nodeWord = valueWordNode->nodeWord;
	ret->next = NULL;
	ret->origType = valueWordNode->origType;
	free(valueWordNode);
	return ret;
}

/* sets the prompt */
parseNode* setpromptCmd(parseNode* newPrompt)
{
	newPrompt->type = setpromptCmdNode;
	newPrompt->next = NULL;
	return newPrompt;
}

/* returns value of specified variable as a wordnode */
parseNode* getVarVal(char* varName)
{
	char* val = getValueOfVar(varName);
	parseNode* ret = malloc(sizeof(parseNode));
	ret->next = NULL;
	ret->type = wordNode;
	ret->nodeWord = val;
	ret->origType = origVariable;

	ret->nextPiped = NULL;
	ret->redirectOutput_flag  = 0;
	ret->redirectInput_flag = 0;
	ret->background_flag = 0;
	ret->redirectOutput = NULL;
	ret->redirectInput = NULL;

	return ret;
}

/* returns a wordnode of the given string */
parseNode* makeWordNode(char* word, eOrigWordType origType)
{
	parseNode* ret = malloc(sizeof(parseNode));
	ret->next = NULL;
	ret->type = wordNode;
	ret->nodeWord = word;
	ret->origType = origType;

	ret->nextPiped = NULL;
        ret->redirectOutput_flag  = 0;
        ret->redirectInput_flag = 0;
        ret->background_flag = 0;
        ret->redirectOutput = NULL;
        ret->redirectInput = NULL;

	return ret;
}

/* simply links firstWordNode to nextWordNode by way of the parseNode->next pointer */
parseNode* linkWordNodes(parseNode* firstWordNode, parseNode* nextWordNode)
{
	firstWordNode->next = nextWordNode;
	return firstWordNode;
}

/* executes the given node(and, if cmd, all nodes pointed to via parseNode->next pointer */
void ex(parseNode* cmd)
{
	if(cmd == NULL)
		return;

	switch( cmd->type ) {
		
			case wordNode:
			{
				int nPipedCommands = 0;
				parseNode* currentPipedCommand = cmd;
				while(currentPipedCommand)
				{
					/* Big loop to go through and construct arg lists for each command of
					   a series of piped commands */

					int nargs = 0;
					char **args_list;
					args_list=NULL;
					parseNode* argsPtr = currentPipedCommand;
					/* first create args array */
					
					if(parsecmd_flag && nPipedCommands > 0)
                                        	printf("Token-type = Metachar\t\tToken=|\t\t\tUsage = pipe\n");


					while(argsPtr)
					{
						if(parsecmd_flag)
						{
						
							if(argsPtr->origType == origMeta)
								printf("Token-type = Metachar\t\tToken=%s\t\t",argsPtr->nodeWord);
							else if(argsPtr->origType == origString)
								printf("Token-type = String\t\tToken=\"%s\"\t\t",argsPtr->nodeWord);
							else
								printf("Token-type = Word\t\tToken=%s\t\t",argsPtr->nodeWord);

							if(nargs == 0)
								printf("Usage = cmd\n");
							else
								printf("Usage = arg %d\n",nargs);
						}
						++nargs;
						args_list = realloc(args_list, nargs*sizeof(char*));
						args_list[nargs-1]=argsPtr->nodeWord;
						argsPtr = argsPtr->next;
					}
					/* suffix args array with null pointer */
	                                args_list = realloc(args_list,(nargs+1)*sizeof(char*));
					args_list[nargs] = NULL;

					currentPipedCommand->myArgsList = args_list;
					currentPipedCommand=currentPipedCommand->nextPiped;
					++nPipedCommands;
				}
				if(parsecmd_flag)
				{
					/* print parsed info for input & output redirection, backgrounding, EOL */
					if(cmd->redirectInput_flag)
					{
						printf("Token-type = Metachar\t\tToken=<\t\t\tUsage = Redirect input\n");
						printf("Token-type = Word\t\tToken=%s\tUsage = Input redirection filename\n",cmd->redirectInput);
					}
					if(cmd->redirectOutput_flag)
					{
						printf("Token-type = Metachar\t\tToken=>\t\t\tUsage = Redirect output\n");
						printf("Token-type = Word\t\tToken=%s\t\tUsage=Output redirection filename\n",cmd->redirectOutput);
					}
					if(cmd->background_flag)
						printf("Token-type = Metachar\t\tToken=&\t\t\tUsage = Background command\n");
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
				}
				if(echocmd_flag)
				{
					currentPipedCommand = cmd;
					while(currentPipedCommand)
					{
						parseNode* argsPtr = currentPipedCommand;
						while(argsPtr)
						{
							printf("%s ",argsPtr->nodeWord);
							argsPtr = argsPtr->next;
						}
						currentPipedCommand = currentPipedCommand->nextPiped;
						if(currentPipedCommand)
							printf(" | ");
					}
					printf("\n");
				}
				int childPID, childStatus;

				int* children = malloc(sizeof(int) * nPipedCommands);
				int childno = 0;
				int pipeEnds[2];
				int lastReadEnd;

				currentPipedCommand = cmd;

				while(currentPipedCommand)
				{
					/* big loop to go through and fork/exec each part of a piped series of commands */
					if(currentPipedCommand->nextPiped)
					{
						/* more commands following this one via pipe, need to open a pipe */
						pipe(pipeEnds);
					}

					/* fork and have children exec process */
					if((childPID = fork()) > 0)
					{
						children[childno] = childPID;
						if(currentPipedCommand->nextPiped)
						{
							/* We opened a pipe, so close the write end */
							close(pipeEnds[1]);

							/* if there was a previous command, close that read end 
							   of its pipe */
							if(childno > 0)
								close(lastReadEnd);

							/* save the current read end, next command will need it */
							lastReadEnd = pipeEnds[0];
						}
						else if(childno > 0)
						{
							/* On the last command, so we didn't open one this time
							   so just close the previous one's read end */
							close(lastReadEnd);
						}

						++childno;
						currentPipedCommand = currentPipedCommand->nextPiped;
						
					}
					else if(childPID == 0)
					{
						if(showchild_flag)
						{
							printf("Handling command with child PID %d\n",getpid());
							/* print child info */
						}

						/* If this command isn't first one, redirect STDIN from previous pipe */
						if(childno > 0)
							dup2(lastReadEnd,STDIN_FILENO);
						else if(childno == 0 && cmd->redirectInput_flag)
						{
							/* if we're on the first one and we have redirection, 
							   handle it here */
							int infd = open(cmd->redirectInput,O_RDONLY);
							if(infd == -1)
								fprintf(stderr,"Cannot open %s for input redirection, will not redirect",cmd->redirectInput);
							else
								dup2(infd,STDIN_FILENO);
						}
						if(currentPipedCommand->nextPiped)
						{
							/* We opened a pipe - need to close the read end 
							   redirect the write end */
							close(pipeEnds[0]);
							dup2(pipeEnds[1],STDOUT_FILENO);
						}
						else if(currentPipedCommand->nextPiped == NULL && cmd->redirectOutput_flag)
						{
							/* if no more commands and output redirection specified,
							   handle it. File is opened in write-only mode such that
							   if it doesn't exist, it's created and if it does, it's
							   set to length 0, and permissions set to 700 */
							int outfd = open(cmd->redirectOutput,O_WRONLY | O_CREAT | O_TRUNC, S_IRWXU);
							if(outfd == -1)
								fprintf(stderr,"Cannot open %s for output redirection. Will not redirect\n",cmd->redirectOutput);
							else
								dup2(outfd,STDOUT_FILENO);
						}
						execvp(currentPipedCommand->myArgsList[0], currentPipedCommand->myArgsList);
						
						/* if we get here something bad happened - execvp should never return */
						if(childno > 0)
							close(lastReadEnd);
						if(currentPipedCommand->nextPiped)
							close(pipeEnds[1]);
						/* errno values sourced from http://linux.die.net/man/2/execve */
						if(errno == ENAMETOOLONG)
							fprintf(stderr,"Command name %s is too long, cannot execute\n", currentPipedCommand->myArgsList[0]);
						else if(errno == ENOMEM)
							fprintf(stderr,"Insufficient kernel memory to execute command %s\n",currentPipedCommand->myArgsList[0]);
						else if(errno == ETXTBSY)
							fprintf(stderr,"The executable for the command %s is opened for writing by one or more processes\n",currentPipedCommand->myArgsList[0]);
						else if(errno == EACCES)
							fprintf(stderr,"Cannot access command %s for execution\n",currentPipedCommand->myArgsList[0]);
						else if(errno == EIO)
							fprintf(stderr,"An IO error occurred while attempting to execute command %s\n",currentPipedCommand->myArgsList[0]);
						else if(errno == ENFILE)
							fprintf(stderr,"The system has reached it's open file limit\n");
						else
							fprintf(stderr,"Cannot find or execute the specified command %s\n",currentPipedCommand->myArgsList[0]);
						exit(1);
					}
					else
					{
						printf("Error, fork() failed!\n");
					}
				}
				int counter;
				if(cmd->background_flag != 1)
				{
					/* if this isn't run in the background, need to reap children */
					for(counter = 0; counter < childno; counter++)
					{
						int wait_status = waitpid((pid_t)children[counter],&childStatus,0);
						if(wait_status == -1)
							printf("Error while waiting on children to exit. Any still running will be run in background");
						else if(showchild_flag)
						{
							if(WIFEXITED(childStatus))
								printf("Child process %d exited normally\n",wait_status);
							else if(WIFSIGNALED(childStatus))
								printf("Child process %d ended because of an uncaught signal\n",wait_status);
							else if(WIFSTOPPED(childStatus))
								printf("Child process %d has stopped\n",wait_status);	
						}
					}
				}
				while(currentPipedCommand)
				{
					/* FREE ALL THE THINGS! */
					free(currentPipedCommand->myArgsList);
					cmd = currentPipedCommand;
					currentPipedCommand = currentPipedCommand->nextPiped;
					while(cmd)
					{
						parseNode* curr = cmd;
						cmd = cmd->next;
						if(curr && curr->nodeWord)
							free(curr->nodeWord);
						if(curr)
							free(curr);
						if(cmd->redirectOutput_flag && cmd->redirectOutput)
							free(cmd->redirectOutput);
						if(cmd->redirectInput_flag && cmd->redirectInput)
							free(cmd->redirectInput);
				
					}
				}
			}
			break;

		case setvarCmdNode:
			{
				if(parsecmd_flag)
				 {

					printf("Token-type = Builtin command\t Token=setvar\t\tUsage = cmd\n");
					printf("Token-type = Variable \t\t Token=$%s\t\tUsage = variable name to set\n",cmd->nodeVariable);
					 
					if(cmd->origType == origMeta)
						printf("Token-type = Metachar\t\tToken=%s\t\tUsage = variable value\n",cmd->nodeWord);
					else if(cmd->origType == origString)
						printf("Token-type = String\t\tToken=\"%s\"\t\tUsage = variable value\n",cmd->nodeWord);
					else
						printf("Token-type = Word\t\tToken=%s\t\tUsage = variable value\n",cmd->nodeWord);
							
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");


				}
				if(echocmd_flag)
					printf("setvar $%s %s\n",cmd->nodeVariable, cmd->nodeWord);

				updateList(cmd->nodeVariable, cmd->nodeWord); 
				if(cmd && cmd->nodeVariable)
					free(cmd->nodeVariable);
				if(cmd && cmd->nodeWord)
					free(cmd->nodeWord);
				if(cmd)
					free(cmd);
			}
			break;
		
		case echocmdCmdNode:
			{
				 if(parsecmd_flag)
                {

					printf("Token-type = Builtin command\t Token=echocmdt\tUsage = cmd\n");
				   
					printf("Token-type = Word\t\t Token=%s\t\tUsage = toggle echocmd\n",cmd->nodeWord);
					
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
                }
				if(echocmd_flag)
					printf("echocmd %s\n",cmd->nodeWord);
					
				if(!strcmp(cmd->nodeWord,"on"))
					echocmd_flag = 1;
				else if(!strcmp(cmd->nodeWord,"off"))
					echocmd_flag = 0;
				else
					printf("%s is not a valid status. Must be \"on\" or \"off\", case sensitive\n",cmd->nodeWord);
				if(cmd && cmd->nodeWord)
					free(cmd->nodeWord);
				if(cmd)
					free(cmd);
			}
			break;
			
		case cdCmdNode:
			{
				if(parsecmd_flag)
                {

					printf("Token-type = Builtin command\t Token=cd\t\t\tUsage = cmd\n");
				   
					printf("Token-type = Word\t\t Token=%s\t\tUsage = Directory\n",cmd->nodeWord);
					
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
                }
				if(echocmd_flag)
					printf("cd %s\n",cmd->nodeWord);
					
				int chdirStatus;
				chdirStatus = chdir(cmd->nodeWord);
				if(chdirStatus == -1)
				{
					/* something went wrong - better check ERRNO and inform user */
					if(errno == ENOENT)
						printf("No such file or directory: %s\n",cmd->nodeWord);
					else if(errno == EPERM)
						printf("Operation not permitted\n");
					else if(errno == ENOTDIR)
						printf("%s is not a directory\n",cmd->nodeWord);
					else if(errno == EINVAL)
						printf("Invalid argument %s to cd\n",cmd->nodeWord);
					else if(errno == EACCES)
						printf("Access is denied\n");
					else if(errno == EIO)
						printf("Input/Output error\n");
					else if(errno == ENOMEM)
						printf("Insufficient memory to change directory\n");
					else
						printf("Error changing directory\n");
				}
				if(cmd && cmd->nodeWord)
					free(cmd->nodeWord);
				if(cmd)
					free(cmd);
			}
			break;

		case parsecmdCmdNode:
			{
				if(parsecmd_flag)
                {

					printf("Token-type = Builtin command\t Token=parsecmd\t\tUsage = cmd\n");
				   
					printf("Token-type = Word\t\t Token=%s\t\tUsage = toggle parsecmd\n",cmd->nodeWord);
					
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
                }
				if(echocmd_flag)
					printf("parsecmd %s\n",cmd->nodeWord);

				if(!strcmp(cmd->nodeWord,"on"))
                                        parsecmd_flag = 1;
                                else if(!strcmp(cmd->nodeWord,"off"))
                                        parsecmd_flag = 0;
                                else
                                        printf("%s is not a valid status. Must be \"on\" or \"off\", case sensitive\n",cmd->nodeWord);
				if(cmd && cmd->nodeWord)
					free(cmd->nodeWord);
				if(cmd)
					free(cmd);
			}
			break;
			
		case showchildCmdNode:
			{
				if(parsecmd_flag)
                {

					printf("Token-type = Builtin command\t Token=showchild\t\tUsage = cmd\n");
				   
					printf("Token-type = Word\t\t Token=%s\t\tUsage = toggle showchild\n",cmd->nodeWord);
					
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
                }
				if(echocmd_flag)
					printf("showchild %s\n",cmd->nodeWord);

				if(!strcmp(cmd->nodeWord,"on"))
						showchild_flag = 1;
				else if(!strcmp(cmd->nodeWord,"off"))
						showchild_flag = 0;
				else
					printf("%s is not a valid status. Must be \"on\" or \"off\", case sensitive\n",cmd->nodeWord);
				
				if(cmd && cmd->nodeWord)
					free(cmd->nodeWord);
				if(cmd)
					free(cmd);
			}
			break;
			
		case exitCmdNode:
			{
				if(parsecmd_flag)
                {
					printf("Token-type = Builtin command\t Token=exit\t\tUsage = cmd\n");
					printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
                }
				if(echocmd_flag)
					printf("exit\n");

				if(cmd)
					free(cmd);
				exit(0);
			}
			break;
			
		case setpromptCmdNode:
			{
				if(parsecmd_flag)
				{
						printf("Token-type = Builtin command\t Token=setprompt\t\tUsage = cmd\n");
						printf("Token-type = Word\t\t Token=%s\t\tUsage = new prompt string\n",cmd->nodeWord);
						printf("Token-type = End-of-line\tToken=EOL\t\tUsage = EOL\n");
				}
				if(echocmd_flag)
					printf("setprompt %s\n",cmd->nodeWord);

				prompt = cmd->nodeWord;
				if(cmd)
					free(cmd);
			}
			break;
	}
	return;
}

/* on error: prints message, restarts parser */
void yyerror(char* s)
{
	printf("%s\n",s);
	printf("%s",prompt);
	yyparse();
	return;
}

/* main driver */
int main(void) 
{
	__head = NULL;
	prompt = strdup("psh % ");
	printf("%s",prompt);
    	yyparse();
	free(prompt);
	freeList();
	return 0;
}
