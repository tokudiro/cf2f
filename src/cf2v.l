%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "SBuf.h"
#include "brace_depth.h"
#include "SBuf_define.h"

static int input(void); /* defined by flex below */

int inBraceCounter = 0;
int in_expression_mode = 0;
int decl_aggregate = 0; /* struct/union/enum keyword seen in the current declaration */

SBuf* word_buffer;
SBuf* caller_function;
SBuf* type_buffer;

void SBuf_append(SBuf* pthis, const char* text, int len) {
    if (pthis->len + len + 2 >= MAX_TEXT) return;
    if (pthis->len > 0 && text[0] != '*') {
        pthis->str[pthis->len] = ' ';
        pthis->len++;
    }
    strncpy(pthis->str + pthis->len, text, len);
    pthis->len += len;
    pthis->str[pthis->len] = '\0';
    pthis->exist = 1;
}

void clear_all() {
    SBuf_init(type_buffer);
    SBuf_init(word_buffer);
    in_expression_mode = 0;
    decl_aggregate = 0;
}

/* True while reading a declaration inside a function body. */
static int in_declaration(void) {
    return in_function_body(inBraceCounter) && !in_expression_mode;
}

/* Skip up to the matching close: call after the open char has been consumed. */
static void skip_balanced(int open, int close) {
    int depth = 1, c;
    while (depth > 0 && (c = input()) != EOF) {
        if (c == open) depth++;
        else if (c == close) depth--;
    }
}

#define TYPEDEF_MAX 256
#define TYPEDEF_NAME_MAX 64
static char typedef_names[TYPEDEF_MAX][TYPEDEF_NAME_MAX];
static int typedef_count = 0;

static void add_typedef(const char* name) {
    int i;
    if (typedef_count >= TYPEDEF_MAX || strlen(name) >= TYPEDEF_NAME_MAX) return;
    for (i = 0; i < typedef_count; i++) {
        if (strcmp(typedef_names[i], name) == 0) return;
    }
    strcpy(typedef_names[typedef_count++], name);
}

static int is_typedef(const char* name) {
    int i;
    for (i = 0; i < typedef_count; i++) {
        if (strcmp(typedef_names[i], name) == 0) return 1;
    }
    return 0;
}

static int is_type_keyword(const char* w) {
    static const char* const kw[] = {
        "char", "double", "float", "int", "long", "short", "signed", "unsigned", "void",
        "_Bool", "_Complex", "struct", "union", "enum", "const", "volatile", "restrict",
        "static", "extern", "register", "auto", "inline", NULL
    };
    int i;
    for (i = 0; kw[i]; i++) if (strcmp(kw[i], w) == 0) return 1;
    return 0;
}

/*
 * Read the rest of a typedef declaration (the 'typedef' keyword is already
 * consumed) up to its ';' and record the names it defines:
 *     typedef int T;   typedef struct { int a; } G, *PG;
 *     typedef int (*CB)(int);   typedef int A[3];
 * Nothing in it is a variable, so no tokens reach the rules.
 */
static void scan_typedef(void) {
    char word[TYPEDEF_NAME_MAX], cand[TYPEDEF_NAME_MAX], fp[TYPEDEF_NAME_MAX];
    int wlen = 0, c = 0, in_word = 0;
    cand[0] = fp[0] = '\0';
    while (c != EOF) {
        c = input();
        if (c != EOF && (isalnum(c) || c == '_')) {
            if (wlen < TYPEDEF_NAME_MAX - 1) word[wlen++] = (char)c;
            in_word = 1;
            continue;
        }
        if (in_word) {
            word[wlen] = '\0';
            if (!isdigit((unsigned char)word[0]) && !is_type_keyword(word)) strcpy(cand, word);
            wlen = in_word = 0;
        }
        if (c == '{') {
            skip_balanced('{', '}');
        } else if (c == '[') {
            skip_balanced('[', ']');
        } else if (c == '(') {
            /* "(*name)" declares name; any other group is a parameter list */
            int depth = 1, k = 0, star = 0, d;
            char name[TYPEDEF_NAME_MAX];
            name[0] = '\0';
            while (depth > 0 && (d = input()) != EOF) {
                if (d == '(') depth++;
                else if (d == ')') depth--;
                else if (depth == 1 && !name[0]) {
                    if (d == '*') star = 1;
                    else if (star && (isalnum(d) || d == '_')) {
                        k = 0;
                        name[k++] = (char)d;
                        while (k < TYPEDEF_NAME_MAX - 1 && (d = input()) != EOF && (isalnum(d) || d == '_')) name[k++] = (char)d;
                        name[k] = '\0';
                        if (d == ')') depth--;
                        else if (d == '(') depth++;
                    }
                }
            }
            if (name[0] && !fp[0]) strcpy(fp, name);
        } else if (c == ',' || c == ';' || c == EOF) {
            if (fp[0]) add_typedef(fp);
            else if (cand[0]) add_typedef(cand);
            cand[0] = fp[0] = '\0';
            if (c == ';') break;
        }
    }
}

static void paren_open(void) {
    if (inBraceCounter == 0) {
        if (SBuf_isExist(word_buffer)) {
            SBuf_setText(caller_function, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
        }
    } else {
        clear_all();
        in_expression_mode = 1;
    }
    clear_all();
}

%}

NONZERO [1-9]
ALPHABET [a-zA-Z]
MOJI     [a-zA-Z_0-9]
COMMENTS (\/\*)
COMMENTE (\*\/)
DIGIT [[:digit:]]
FLOAT ({NONZERO}{DIGIT}*\.?|0\.|\.{DIGIT}){DIGIT}*|0
FLOATE [fF]
HEX [a-fA-F0-9]

NUMBER {FLOAT}{FLOATE}?|0x{HEX}*
WSPACE [[:blank:]]+
WORD ({ALPHABET}{MOJI}*)
FUNCPTR "("[[:blank:]]*"*"[[:blank:]*]*{WORD}[[:blank:]]*")"[[:blank:]]*"("

PRICOMPILE #{WORD}

COMMENT (\/\/)

%option yylineno

%s COMMENT_SA
%s COMMENT_SS
%s STRING_ST
%s STRING_SS
%s PRICOMPILER

%%
<INITIAL>{
    {NUMBER} { SBuf_init(word_buffer); }
    {WSPACE} { }
    {COMMENTS} { SBuf_init(word_buffer); BEGIN(COMMENT_SA); }
    {COMMENT}  { SBuf_init(word_buffer); BEGIN(COMMENT_SS); }
    \" { SBuf_init(word_buffer); BEGIN(STRING_ST); }
    \' { SBuf_init(word_buffer); BEGIN(STRING_SS); }
    {PRICOMPILE} { brace_depth_directive(yytext, &inBraceCounter); BEGIN(PRICOMPILER); }

    "break"|"case"|"continue"|"default"|"do"|"else"|"for"|"goto"|"if"|"return"|"switch"|"while"|"sizeof" {
        clear_all();
        in_expression_mode = 1;
    }

    "typedef" {
        clear_all();
        scan_typedef();
    }

    "char"|"double"|"float"|"int"|"long"|"short"|"signed"|"unsigned"|"void"|"_Bool"|"_Complex"|"struct"|"union"|"enum"|"const"|"volatile"|"restrict"|"static"|"extern"|"register"|"auto"|"inline" {
        if (strcmp(yytext, "struct") == 0 || strcmp(yytext, "union") == 0 || strcmp(yytext, "enum") == 0) {
            top_aggregate_keyword(inBraceCounter);
            if (in_declaration()) decl_aggregate = 1;
        }
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            SBuf_append(type_buffer, yytext, yyleng);
        }
    }

    "*" {
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            if (SBuf_getLen(word_buffer) > 0) {
                SBuf_append(type_buffer, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
                SBuf_init(word_buffer);
            }
            SBuf_append(type_buffer, "*", 1);
        }
    }

    {WORD} {
        /* a known type name starts a declaration, e.g. after "case 1:" */
        if (in_function_body(inBraceCounter) && in_expression_mode
            && SBuf_getLen(word_buffer) == 0 && SBuf_getLen(type_buffer) == 0 && is_typedef(yytext)) {
            in_expression_mode = 0;
        }
        if (in_function_body(inBraceCounter)) {
            if (!in_expression_mode) {
                if (SBuf_getLen(word_buffer) > 0) {
                    SBuf_append(type_buffer, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
                }
                SBuf_setText(word_buffer, yytext, yyleng);
            }
        } else {
            SBuf_setText(word_buffer, yytext, yyleng);
        }
    }

    {FUNCPTR} {
        /* int (*fp)(int);  -- declare fp and skip the parameter list */
        if (in_declaration() && (SBuf_getLen(type_buffer) > 0 || SBuf_getLen(word_buffer) > 0)) {
            int end = yyleng - 1, start;
            while (yytext[end] != ')') end--;
            start = end;
            while (isalnum((unsigned char)yytext[start - 1]) || yytext[start - 1] == '_') start--;
            if (SBuf_getLen(word_buffer) > 0) {
                SBuf_append(type_buffer, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
            }
            SBuf_setText(word_buffer, yytext + start, end - start);
            skip_balanced('(', ')');
        } else {
            yyless(1);
            paren_open();
        }
    }

    "(" {
        paren_open();
    }

    ")" {
        top_close_paren(inBraceCounter);
        SBuf_init(word_buffer);
    }

    "{"|"<%" {
        if (in_declaration() && decl_aggregate) {
            /* struct/union/enum [tag] { ... } var;  -- members are not variables */
            skip_balanced('{', '}');
            if (SBuf_getLen(word_buffer) > 0) {
                SBuf_append(type_buffer, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
                SBuf_init(word_buffer);
            }
            decl_aggregate = 0;
        } else {
        top_open_brace(inBraceCounter);
        inBraceCounter++;
        clear_all();
        }
    }

    "}"|"%>" {
        int was_open = inBraceCounter > 0; if (was_open) inBraceCounter--;
        clear_all();
        if (was_open && inBraceCounter == 0) {
            if (top_close_brace_is_function() && SBuf_getLen(caller_function)) {
                printf("\t\"%s()\"[color=red];\n", SBuf_getText(caller_function));
            }
        }
    }

    "=" {
        top_assign_op(inBraceCounter);
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            if (SBuf_getLen(type_buffer) > 0 && SBuf_getLen(word_buffer) > 0) {
                printf("\t\"%s()\" -> \"%s %s\"\n", SBuf_getText(caller_function), SBuf_getText(type_buffer), SBuf_getText(word_buffer));
            }
        }
        SBuf_init(word_buffer);
        in_expression_mode = 1;
    }

    "," {
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            if (SBuf_getLen(type_buffer) > 0 && SBuf_getLen(word_buffer) > 0) {
                printf("\t\"%s()\" -> \"%s %s\"\n", SBuf_getText(caller_function), SBuf_getText(type_buffer), SBuf_getText(word_buffer));
            }
        }
        SBuf_init(word_buffer);
        in_expression_mode = 0;
    }

    ";" {
        top_semicolon(inBraceCounter);
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            if (SBuf_getLen(type_buffer) > 0 && SBuf_getLen(word_buffer) > 0) {
                printf("\t\"%s()\" -> \"%s %s\"\n", SBuf_getText(caller_function), SBuf_getText(type_buffer), SBuf_getText(word_buffer));
            }
        }
        clear_all();
    }

    "..."|">>="|"<<="|"+="|"-="|"*="|"/="|"%="|"&="|"^="|"|="|">>"|"<<"|"++"|"--"|"->"|"&&"|"||"|"<="|">="|"=="|"!=" {
        clear_all();
        if (inBraceCounter > 0) {
            in_expression_mode = 1;
        }
    }

    "["|"<:" {
        if (in_declaration() && SBuf_getLen(word_buffer) > 0) {
            skip_balanced('[', ']');
        } else {
            SBuf_init(word_buffer);
        }
    }

    "]"|":>"|"."|"&"|"!"|"~"|"+"|"-"|"/"|"%"|"<"|">"|"^"|"|"|"?"|":" {
        SBuf_init(word_buffer);
    }

    \n { }
    .  { }
}

<PRICOMPILER>{
    \\\r?\n { }
    \n { BEGIN(INITIAL); }
    . { }
}

<COMMENT_SA>{
    {COMMENTE} { BEGIN(INITIAL); }
    \n { }
    . { }
}

<COMMENT_SS>{
    \\\r?\n { }
    \n { BEGIN(INITIAL); }
    . { }
}

<STRING_ST>{
    \\\\ { }
    \\\" { }
    \" { BEGIN(INITIAL); }
    . { }
}

<STRING_SS>{
    \\\\ { }
    \\\' { }
    \' { BEGIN(INITIAL); }
    . { }
}

<<EOF>> {
    return 0;
}

%%
