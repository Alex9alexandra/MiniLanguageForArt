%{
#include <stdio.h>
#include <stdlib.h>

/* defined in scanner.l */
int yylex(void);
extern FILE *prodFile;/* output file with the string of productions */
extern FILE *errFile;/* output file with the errors */
extern int line;/* current line of the source program */
extern int errorCount;/* lexical errors found so far */

void yyerror(const char *message);

/* Writes one production on the screen and in the production file. The productions appear in the order in which the parser applies them. */
static void prod(const char *production) {
    printf("%s\n", production);
    fprintf(prodFile, "%s\n", production);
}
%}

%error-verbose
%define lr.default-reductions accepting

/* keywords */
%token IF IN LOAD PAINTING_WHILE EMPTY PAINT PASTE GIVE_TO VIEW MIX
/*symbols:  -  >  <  *  [  ]  ,  */
%token MINUS GT LT STAR LBRACKET RBRACKET COMMA
/* identifiers and constants (recognized by the finite automata) */
%token ID NUMBER COLOR
/* returned by the scanner after a lexical error; no rule accepts it, so parsing stops */
%token LEXERROR

%start program

%%

program
    : statement_list                         { prod("program -> statement_list"); }
    ;

statement_list
    : statement                              { prod("statement_list -> statement"); }
    | statement_list statement               { prod("statement_list -> statement_list statement"); }
    ;

statement
    : loop_statement                         { prod("statement -> loop_statement"); }
    | conditional_statement                  { prod("statement -> conditional_statement"); }
    | color_assignment_statement             { prod("statement -> color_assignment_statement"); }
    | canvas_assignment_statement            { prod("statement -> canvas_assignment_statement"); }
    | canvas_assignment_statement_full       { prod("statement -> canvas_assignment_statement_full"); }
    | input                                  { prod("statement -> input"); }
    | output                                 { prod("statement -> output"); }
    | definition                             { prod("statement -> definition"); }
    | operation                              { prod("statement -> operation"); }
    ;

conditional_statement
    : IF MINUS expression MINUS GT block LT  { prod("conditional_statement -> IF MINUS expression MINUS GT block LT"); }
    ;

loop_statement
    : PAINTING_WHILE MINUS expression MINUS GT block LT
                                             { prod("loop_statement -> PAINTING_WHILE MINUS expression MINUS GT block LT"); }
    ;

expression
    : content_check_color_expression         { prod("expression -> content_check_color_expression"); }
    | content_check_canvas_expression        { prod("expression -> content_check_canvas_expression"); }
    ;

content_check_color_expression
    : IN color_identifier COLOR              { prod("content_check_color_expression -> IN color_identifier COLOR"); }
    ;

content_check_canvas_expression
    : EMPTY canvas_identifier                { prod("content_check_canvas_expression -> EMPTY canvas_identifier"); }
    ;

block
    : statement_list                         { prod("block -> statement_list"); }
    ;

color_assignment_statement
    : LOAD color_identifier COLOR            { prod("color_assignment_statement -> LOAD color_identifier COLOR"); }
    ;

canvas_assignment_statement
    : PAINT canvas_identifier color_identifier
                                             { prod("canvas_assignment_statement -> PAINT canvas_identifier color_identifier"); }
    ;

canvas_assignment_statement_full
    : PASTE canvas_identifier canvas         { prod("canvas_assignment_statement_full -> PASTE canvas_identifier canvas"); }
    ;

input
    : GIVE_TO identifier                     { prod("input -> GIVE_TO identifier"); }
    ;

output
    : VIEW identifier                        { prod("output -> VIEW identifier"); }
    ;

definition
    : color_definition                       { prod("definition -> color_definition"); }
    | canvas_definition                      { prod("definition -> canvas_definition"); }
    ;

color_definition
    : STAR color_identifier                  { prod("color_definition -> STAR color_identifier"); }
    ;

canvas_definition
    : LBRACKET NUMBER RBRACKET canvas_identifier
                                             { prod("canvas_definition -> LBRACKET NUMBER RBRACKET canvas_identifier"); }
    ;

operation
    : MIX color_identifier color_identifier  { prod("operation -> MIX color_identifier color_identifier"); }
    ;

canvas
    : LBRACKET color_list RBRACKET           { prod("canvas -> LBRACKET color_list RBRACKET"); }
    ;

color_list
    : COLOR                                  { prod("color_list -> COLOR"); }
    | color_list COMMA COLOR                 { prod("color_list -> color_list COMMA COLOR"); }
    ;

identifier
    : ID                                     { prod("identifier -> ID"); }
    ;

canvas_identifier
    : ID                                     { prod("canvas_identifier -> ID"); }
    ;

color_identifier
    : ID                                     { prod("color_identifier -> ID"); }
    ;

%%

/* Called by the parser at the first syntax error (parsing stops). */
void yyerror(const char *message) {
    if (errorCount > 0) {
        /*the scanner already reported the lexical error */
        printf("Parsing stopped because of the lexical error above.\n");
        fprintf(errFile, "Parsing stopped because of a lexical error.\n");
    } else {
        printf("Syntax error at line %d: %s\n", line, message);
        fprintf(errFile, "Syntax error at line %d: %s\n", line, message);
    }
}