#pragma once
#ifndef SYMTAB_H
#define SYMTAB_H

#include <stdio.h>

/* One node of the binary search tree: one symbol (identifier or constant). */
typedef struct Node {
    char* symbol;          /* the text, c1 or "red"... */
    int position;          /* running counter value given at insertion */
    struct Node* left;     /* symbols smaller than this one (strcmp < 0) */
    struct Node* right;    /* symbols larger than this one (strcmp > 0) */
} Node;

/* The symbol table: the root of the tree + how many symbols it holds. */
typedef struct {
    Node* root;
    int count;             /* also the position the next new symbol receives */
} SymbolTable;

/* Creates an empty table. */
void st_init(SymbolTable* st);

/* Inserts the symbol if it is new, and returns its position.
   If it already exists, nothing is added and the existing position is returned. */
int st_insert(SymbolTable* st, const char* symbol);

/* Returns the position of the symbol, or -1 if it is not in the table. */
int st_search(const SymbolTable* st, const char* symbol);

/* Writes every symbol with its position, in alphabetical order (in-order traversal). */
void st_print(const SymbolTable* st, FILE* out);

/* Releases all the memory used by the table. */
void st_free(SymbolTable* st);

#endif