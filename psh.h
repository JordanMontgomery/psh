/*
 *		psh.h - Main header for pipe shell including necessary global data,
 *		etc.
  * 	By Elijah Montgomery
 */

#ifndef PSH_H
#define PSH_H

/* Enum that defines the node's type */
typedef enum eNodeType { wordNode, setvarCmdNode, echocmdCmdNode, cdCmdNode, parsecmdCmdNode,
		 showchildCmdNode, exitCmdNode, setpromptCmdNode } eNodeType;

/* Enum that define's a word node's original type(string, metachar, variable, word ) */
typedef enum eOrigWordType { origVariable, origWord, origString, origMeta } eOrigWordType;

/* global flags */
short parsecmd_flag;
short echocmd_flag;
short showchild_flag;

/* global prompt string */
char * prompt;


/* node struct used by Flex/Bison to build AST
 * some memory is wasted, as not all fields are needed for each command but for the sake of
 * readability and ease of maintenance this will be ignored for now
 */
typedef struct parseNode {
        	struct parseNode* next;	//next node of single command
		struct parseNode* nextPiped; //next command of piped series of commands
		char* nodeWord;
		char* nodeVariable;
		char* nodeValue;
		enum eNodeType type;
		enum eOrigWordType origType; //whether node was originally word, string, variable or metachar
		short background_flag;	//Flag to background command or not
		short redirectInput_flag;
		char* redirectInput;	//where to redirect input from
		short redirectOutput_flag; 
		char* redirectOutput;	//Where to redirect output to
		char** myArgsList;	//used by ex() to handle args list for each piece of a command to support pipes
} parseNode;

#endif
