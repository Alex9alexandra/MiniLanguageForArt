%option noyywrap nounistd
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "symbolTable.h"
#include "fa.h"
#include "parser.tab.h" /* token names of the parser: IF, ID, COLOR ... (made by bison) */

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
FILE *errFile;/* used by the parser too (parser.y) */
FILE *prodFile; /* the string of productions, written by the parser */
int line = 1; /* used by the parser for the error messages */
int errorCount = 0;
static FA identifierFA, numberFA, colorFA;

static int scan_with_fa(const FA *fa, int pifCode, int parserToken);

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

"IF"               { emit(T_IF, -1); return IF; }
"IN"               { emit(T_IN, -1); return IN; }
"LOAD"             { emit(T_LOAD, -1); return LOAD; }
"PAINTING_WHILE"   { emit(T_PAINTING_WHILE, -1); return PAINTING_WHILE; }
"EMPTY"            { emit(T_EMPTY, -1); return EMPTY; }
"PAINT"            { emit(T_PAINT, -1); return PAINT; }
"PASTE"            { emit(T_PASTE, -1); return PASTE; }
"GIVE_TO"          { emit(T_GIVE_TO, -1); return GIVE_TO; }
"VIEW"             { emit(T_VIEW, -1); return VIEW; }
"MIX"              { emit(T_MIX, -1); return MIX; }

"-"                { emit(T_MINUS, -1); return MINUS; }
">"                { emit(T_GREATER, -1); return GT; }
"<"                { emit(T_LESS, -1); return LT; }
"*"                { emit(T_STAR, -1); return STAR; }
"["                { emit(T_LBRACKET, -1); return LBRACKET; }
"]"                { emit(T_RBRACKET, -1); return RBRACKET; }
","                { emit(T_COMMA, -1); return COMMA; }

    /* Identifiers and constants are recognized by the finite automata.
       flex only detects the first character; scan_with_fa runs the FA from there
       and returns the token for the parser (ID, NUMBER or COLOR). */
[a-z]              { return scan_with_fa(&identifierFA, T_IDENTIFIER, ID); }
[1-9]              { return scan_with_fa(&numberFA, T_CONSTANT, NUMBER); }
\"                 { return scan_with_fa(&colorFA, T_CONSTANT, COLOR); }

0[0-9]*                          { report("number cannot start with 0 (a canvas size must be 1 or more)"); return LEXERROR; }
0[0-9]*[a-zA-Z_][a-zA-Z0-9_]*    { report("identifier cannot start with a digit"); return LEXERROR; }
[A-Z_][a-zA-Z0-9_]*              { report("invalid identifier or unknown keyword"); return LEXERROR; }

[ \t\r]+           { /* whitespace is ignored */ }
\n                 { line++; }
.                  { report("unexpected character"); return LEXERROR; }

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

/* Returns the token for the parser, or LEXERROR if the word is invalid.
   Runs the automaton on the input, starting with the character flex already read
   (yytext[0]). It follows the transitions as long as there are any (input() reads the
   next character, unput() gives one back). The word is valid if the FA stops in a final
   state and the next character cannot continue the word. */
static int scan_with_fa(const FA *fa, int pifCode, int parserToken) {
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
        emit_text(pifCode, st_insert(&st, text), text);
        return parserToken;
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
    return LEXERROR;
}

int main(int argc, char *argv[]) {
    const char *source = (argc > 1) ? argv[1] : "ProgramExemple_works.txt";
    char pifName[300], stName[300], errName[300], prodName[300];
    FILE *stFile;
    int result;

    snprintf(pifName, sizeof(pifName), "%s.pif.txt", source);
    snprintf(stName, sizeof(stName), "%s.st.txt", source);
    snprintf(errName, sizeof(errName), "%s.err.txt", source);
    snprintf(prodName, sizeof(prodName), "%s.prod.txt", source);

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
    prodFile = fopen(prodName, "w");
    if (pifFile == NULL || stFile == NULL || errFile == NULL || prodFile == NULL) {
        printf("Cannot create the output files\n");
        return 1;
    }

    st_init(&st);
    fprintf(pifFile, "(code, ST position)\ttoken\n");
    result = yyparse();/* the parser asks the scanner (yylex) for tokens */

    st_print(&st, stFile);

    if (result == 0) {
        printf("%s was parsed successfully.\n", source);
        fprintf(errFile, "No lexical or syntax errors.\n");
    } else {
        printf("Parsing of %s stopped at the first error.\n", source);
    }

    fclose(yyin);
    fclose(pifFile);
    fclose(stFile);
    fclose(errFile);
    fclose(prodFile);
    st_free(&st);
    return 0;
}