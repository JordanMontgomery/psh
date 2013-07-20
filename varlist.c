/* 	Simple symbol table - implementation for Verbose Shell project
 *	By Elijah Montgomery
 *
 *	Creates a simple, singly linked list to use as a symbol table
 *	for storage and lookup of shell variables 
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "varlist.h"


/* only needed for testing purposes */

void freeList()
{
        while(__head)
        {
                listNode * curr = __head;
                __head = curr->next;
                if(curr->varName)
                {
                        free(curr->varName);
                        curr->varName = NULL;
                }
                if(curr->varVal)
                {
                        free(curr->varVal);
                        curr->varVal = NULL;
                }
                free(curr);
        }
}

void printList()
{
        listNode* curr = __head;
        while(curr)
        {
                printf("%s %s\n",curr->varName,curr->varVal);
                curr = curr->next;
        }
}

void updateList(const char * name, const char*value)
{
        listNode * curr = __head;
        char * myName = NULL;
        char * myValue = NULL;
        myName = strdup(name);
        myValue = strdup(value);
        while(curr)
        {
                int nLen = MAX_2(strlen(myName),strlen(curr->varName));
                if(!strncmp(myName,curr->varName,nLen))
                {       /* Already exists - found it! */
                        if(curr->varVal)
                                free(curr->varVal);
                        curr->varVal = myValue;
                        if(myName)
                                free(myName);
                        return;
                }
                curr = curr->next;
        }
        /*doesn't exist - create a new node */
        curr = malloc(sizeof(listNode));
        curr->varVal = myValue;
        curr->varName = myName;
        curr->next = __head;
        __head = curr;
        return;
}

char* getValueOfVar(const char* name)
{
	listNode* curr = __head;
	while(curr)
	{
		int nLen = MAX_2(strlen(name),strlen(curr->varName));
		if(!strncmp(name,curr->varName,nLen))
		{
			return strdup(curr->varVal);
		}
		curr = curr->next;
	}
	return strdup("");
}

int countVariables()
{
	int n = 0;
	listNode* curr = __head;
	while(curr)
	{
		n++;
		curr = curr->next;
	}
	return n;
}
