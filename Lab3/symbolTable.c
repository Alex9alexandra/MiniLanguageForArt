#include <stdlib.h>
#include <string.h>
#include "symbolTable.h"

void st_init(SymbolTable* st) {
    st->root = NULL;
    st->count = 0;
}

static Node* new_node(const char* symbol, int position) {
    Node* n = (Node*)malloc(sizeof(Node));
    if (n == NULL) {
        fprintf(stderr, "out of memory\n");
        exit(1);
    }
    n->symbol = (char*)malloc(strlen(symbol) + 1);
    if (n->symbol == NULL) {
        fprintf(stderr, "out of memory\n");
        exit(1);
    }
    strcpy(n->symbol, symbol);
    n->position = position;
    n->left = NULL;
    n->right = NULL;
    return n;
}

int st_insert(SymbolTable* st, const char* symbol) {
    if (st->root == NULL) {
        st->root = new_node(symbol, st->count);
        return st->count++;
    }

    Node* current = st->root;
    while (1) {
        int cmp = strcmp(symbol, current->symbol);
        if (cmp == 0) {
            return current->position;          
        }
        else if (cmp < 0) {
            if (current->left == NULL) {
                current->left = new_node(symbol, st->count);
                return st->count++;
            }
            current = current->left;
        }
        else {
            if (current->right == NULL) {
                current->right = new_node(symbol, st->count);
                return st->count++;
            }
            current = current->right;
        }
    }
}

int st_search(const SymbolTable* st, const char* symbol) {
    Node* current = st->root;
    while (current != NULL) {
        int cmp = strcmp(symbol, current->symbol);
        if (cmp == 0) {
            return current->position;
        }
        current = (cmp < 0) ? current->left : current->right;
    }
    return -1;
}

static void print_node(const Node* n, FILE* out) {
    if (n == NULL) {
        return;
    }
    print_node(n->left, out);                    
    fprintf(out, "%-20s %d\n", n->symbol, n->position);
    print_node(n->right, out);                  
}

void st_print(const SymbolTable* st, FILE* out) {
    fprintf(out, "%-20s %s\n", "Symbol", "Position");
    print_node(st->root, out);
}

static void free_node(Node* n) {
    if (n == NULL) {
        return;
    }
    free_node(n->left);
    free_node(n->right);
    free(n->symbol);
    free(n);
}

void st_free(SymbolTable* st) {
    free_node(st->root);
    st->root = NULL;
    st->count = 0;
}