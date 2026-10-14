%option noyywrap nounistd

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbolTable.h"

/* Token codes (same numbering as the token list file) */
#define T_IDENTIFIER      0
#define T_CONSTANT        1
#define T_IF              2
#define T_IN              3
#define T_LOAD            4
#define T_PAINTING_WHILE  5
#define T_EMPTY           6
#define T_PAINT           7
#define T_PASTE           8
#define T_GIVE_TO         9
#define T_VIEW            10
#define T_MIX             11
#define T_MINUS           12
#define T_GREATER         13
#define T_LESS            14
#define T_STAR            15
#define T_LBRACKET        16
#define T_RBRACKET        17
#define T_COMMA           18

static SymbolTable st;
static FILE *pifFile;
static FILE *errFile;
static int line = 1;
static int errorCount = 0;

/* Writes one pair (code, ST position) to the PIF, followed by the token text. */
static void emit(int code, int position) {
    fprintf(pifFile, "(%d, %d)\t%s\n", code, position, yytext);
}

/* Reports a lexical error on the screen and in the error file. */
static void report(const char *message) {
    errorCount++;
    printf("Lexical error at line %d: %s: '%s'\n", line, message, yytext);
    fprintf(errFile, "Lexical error at line %d: %s: '%s'\n", line, message, yytext);
}
%}

%%

"IF"               { emit(T_IF, -1); }
"IN"               { emit(T_IN, -1); }
"LOAD"             { emit(T_LOAD, -1); }
"PAINTING_WHILE"   { emit(T_PAINTING_WHILE, -1); }
"EMPTY"            { emit(T_EMPTY, -1); }
"PAINT"            { emit(T_PAINT, -1); }
"PASTE"            { emit(T_PASTE, -1); }
"GIVE_TO"          { emit(T_GIVE_TO, -1); }
"VIEW"             { emit(T_VIEW, -1); }
"MIX"              { emit(T_MIX, -1); }

"-"                { emit(T_MINUS, -1); }
">"                { emit(T_GREATER, -1); }
"<"                { emit(T_LESS, -1); }
"*"                { emit(T_STAR, -1); }
"["                { emit(T_LBRACKET, -1); }
"]"                { emit(T_RBRACKET, -1); }
","                { emit(T_COMMA, -1); }

[a-z][a-z0-9]*     { int pos = st_insert(&st, yytext); emit(T_IDENTIFIER, pos); }

[1-9][0-9]*        { int pos = st_insert(&st, yytext); emit(T_CONSTANT, pos); }

\"(red|blue|yellow|green|violet|orange|brown)\"   { int pos = st_insert(&st, yytext); emit(T_CONSTANT, pos); }

0[0-9]*                          { report("number cannot start with 0 (a canvas size must be 1 or more)"); }
[0-9]+[a-zA-Z_][a-zA-Z0-9_]*     { report("identifier cannot start with a digit"); }
\"[^"\n]*\"                      { report("invalid color constant"); }
\"[^"\n]*                        { report("unclosed color constant"); }
[a-zA-Z_][a-zA-Z0-9_]*           { report("invalid identifier or unknown keyword"); }

[ \t\r]+           { /* whitespace is ignored */ }
\n                 { line++; }
.                  { report("unexpected character"); }

%%

int main(int argc, char *argv[]) {
    const char *source = (argc > 1) ? argv[1] : "ProgramExemple_works.txt";
    char pifName[300], stName[300], errName[300];
    FILE *stFile;

    snprintf(pifName, sizeof(pifName), "%s.pif.txt", source);
    snprintf(stName, sizeof(stName), "%s.st.txt", source);
    snprintf(errName, sizeof(errName), "%s.err.txt", source);

    yyin = fopen(source, "r");
    if (yyin == NULL) {
        printf("Cannot open the source file '%s'\n", source);
        return 1;
    }
    pifFile = fopen(pifName, "w");
    stFile = fopen(stName, "w");
    errFile = fopen(errName, "w");
    if (pifFile == NULL || stFile == NULL || errFile == NULL) {
        printf("Cannot create the output files\n");
        return 1;
    }

    st_init(&st);
    fprintf(pifFile, "(code, ST position)\ttoken\n");

    yylex();

    st_print(&st, stFile);

    if (errorCount == 0) {
        printf("%s is lexically correct.\n", source);
        fprintf(errFile, "No lexical errors.\n");
    } else {
        printf("%d lexical error(s) found in %s.\n", errorCount, source);
        fprintf(errFile, "%d lexical error(s) found.\n", errorCount);
    }

    fclose(yyin);
    fclose(pifFile);
    fclose(stFile);
    fclose(errFile);
    st_free(&st);
    return 0;
}