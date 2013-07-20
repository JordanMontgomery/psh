/*
 *	varlist.h - Header for simple symbol table for verbose shell.
 *	By Elijah Montgomery
 */
#ifndef VARLIST_H
#define VARLIST_H

#define MAX_2(A,B) (((A) > (B))? (A) : (B))

/* singly-linked list. Each node carries name, value */
typedef struct listNode {
        struct listNode* next;
        char* varName;
        char* varVal;
} listNode;

/* global head of list */
listNode * __head;

/* deletes all nodes & allocated strings. We can do this here because all strings are copied before insertion */
void freeList(); 

/* prints name and value of each node. Helpful for debug purposes */
void printList(); 

/* 
 * Adds/updates(if name already exists) function is case sensitive!
 * updateList() always makes a copy of the name/value, so delete the one passed in
 * if you need to. This allows it to manage its own memory to guard against memory leaks
 */
void updateList(const char* name, const char* value); 
 
 /* Returns either a copy of the string representing the value, or empty string otherwise */
char* getValueOfVar(const char* name);

/* counts the number of nodes. Only useful for debug purposes */
int countVariables();

#endif /* VARLIST_H */

