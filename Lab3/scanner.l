%option noyywrap nounistd
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "symbolTable.h"
#include "fa.h"

/* The three automata, loaded from files when the program starts */
#define IDENTIFIER_FA_FILE "identifier.fa.txt"
#define NUMBER_FA_FILE     "number.fa.txt"
#define COLOR_FA_FILE      "color.fa.txt"
#define MAX_TOKEN          255   /* longest identifier/constant accepted */

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
static FA identifierFA, numberFA, colorFA;

static void scan_with_fa(const FA *fa, int tokenCode);

/* Writes one pair (code, ST position) to the PIF, followed by the token text. */
static void emit_text(int code, int position, const char *text) {
    fprintf(pifFile, "(%d, %d)\t%s\n", code, position, text);
}
static void emit(int code, int position) { emit_text(code, position, yytext); }

/* Reports a lexical error on the screen and in the error file. */
static void report_text(const char *message, const char *text) {
    errorCount++;
    printf("Lexical error at line %d: %s: '%s'\n", line, message, text);
    fprintf(errFile, "Lexical error at line %d: %s: '%s'\n", line, message, text);
}
static void report(const char *message) { report_text(message, yytext); }
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

    /* Identifiers and constants are recognized by the finite automata.
       flex only detects the first character; scan_with_fa runs the FA from there. */
[a-z]              { scan_with_fa(&identifierFA, T_IDENTIFIER); }
[1-9]              { scan_with_fa(&numberFA, T_CONSTANT); }
\"                 { scan_with_fa(&colorFA, T_CONSTANT); }

0[0-9]*                          { report("number cannot start with 0 (a canvas size must be 1 or more)"); }
0[0-9]*[a-zA-Z_][a-zA-Z0-9_]*    { report("identifier cannot start with a digit"); }
[A-Z_][a-zA-Z0-9_]*              { report("invalid identifier or unknown keyword"); }

[ \t\r]+           { /* whitespace is ignored */ }
\n                 { line++; }
.                  { report("unexpected character"); }

%%

/* A character that can be part of a word: if the FA stops in front of one, the word is invalid. */
static int is_word_char(int c) {
    return isalnum(c) || c == '_' || c == '"';
}

/* Chooses the error message for an invalid identifier/constant. */
static const char *describe_error(const char *text, int tooLong) {
    const char *p;
    if (tooLong) return "token too long";
    if (text[0] == '"') {
        return strchr(text + 1, '"') ? "invalid color constant" : "unclosed color constant";
    }
    if (isdigit((unsigned char)text[0])) {
        for (p = text; *p; p++) {
            if (isalpha((unsigned char)*p) || *p == '_') return "identifier cannot start with a digit";
        }
        return "invalid number";
    }
    return "invalid identifier or unknown keyword";
}

/* Runs the automaton on the input, starting with the character flex already read
   (yytext[0]). It follows the transitions as long as there are any (input() reads the
   next character, unput() gives one back). The word is valid if the FA stops in a final
   state and the next character cannot continue the word. */
static void scan_with_fa(const FA *fa, int tokenCode) {
    char text[MAX_TOKEN + 1];
    int len = 0, tooLong = 0;
    int state = fa->start;
    int c = (unsigned char)yytext[0];
    int pending;                              /* the first character the FA could not use */

    while (1) {
        int next = fa_step(fa, state, c);
        if (next < 0) {                       /* no transition: the FA stops here */
            pending = c;
            break;
        }
        if (len < MAX_TOKEN) text[len++] = (char)c; else tooLong = 1;
        state = next;
        c = input();
        if (c == EOF || c == 0) {             /* end of the file */
            pending = EOF;
            break;
        }
    }

    if (fa_is_final(fa, state) && !tooLong && !(pending != EOF && is_word_char(pending))) {
        text[len] = '\0';
        if (pending != EOF) unput(pending);
        emit_text(tokenCode, st_insert(&st, text), text);
        return;
    }

    /* Invalid word: read the rest of it, so that it is reported only once. */
    c = pending;
    while (c != EOF && c != 0 && is_word_char(c)) {
        if (len < MAX_TOKEN) text[len++] = (char)c; else tooLong = 1;
        c = input();
    }
    if (c != EOF && c != 0) unput(c);
    text[len] = '\0';
    report_text(describe_error(text, tooLong), text);
}

int main(int argc, char *argv[]) {
    const char *source = (argc > 1) ? argv[1] : "ProgramExemple_works.txt";
    char pifName[300], stName[300], errName[300];
    FILE *stFile;

    snprintf(pifName, sizeof(pifName), "%s.pif.txt", source);
    snprintf(stName, sizeof(stName), "%s.st.txt", source);
    snprintf(errName, sizeof(errName), "%s.err.txt", source);

    /* load the three automata (files from Lab 4) */
    if (!fa_load(&identifierFA, IDENTIFIER_FA_FILE) ||
        !fa_load(&numberFA, NUMBER_FA_FILE) ||
        !fa_load(&colorFA, COLOR_FA_FILE)) {
        return 1;
    }

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