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

/*
 * Variable uses.  Every identifier read inside a function body is held in
 * "pending" until the end of the statement (';', '{', '}'); then those that
 * are not declared in the function (parameters, locals in enclosing blocks)
 * are reported as non-local variables: "f()" -> "name".
 * Declarations are recognized by the type_buffer/word_buffer heuristic.
 */
#define NAME_MAX_LEN 64
#define NAMES_MAX 256
#define SCOPE_DEPTH_MAX 64

static char scope_names[NAMES_MAX][NAME_MAX_LEN];
static int scope_count = 0;
static int scope_marks[SCOPE_DEPTH_MAX];

static char param_names[NAMES_MAX][NAME_MAX_LEN];
static int param_count = 0;

static char pending[NAMES_MAX][NAME_MAX_LEN];
static int pending_count = 0;

static int after_member = 0;   /* previous token was '.' or '->' */
static int skip_next_word = 0; /* previous token was 'goto' */
static int for_pending = 0;    /* previous token was 'for' */
static int head_closed = 0;    /* top level: a '(...)' was just read; K&R parameter declarations may follow */

static void add_name(char (*list)[NAME_MAX_LEN], int* count, const char* name) {
    if (*count >= NAMES_MAX || strlen(name) >= NAME_MAX_LEN) return;
    strcpy(list[(*count)++], name);
}

static int has_name(char (*list)[NAME_MAX_LEN], int count, const char* name) {
    int i;
    for (i = 0; i < count; i++) if (strcmp(list[i], name) == 0) return 1;
    return 0;
}

/* ALL_CAPS names are taken to be macros or constants, not variables. */
static int is_macro_like(const char* name) {
    int letters = 0;
    for (; *name; name++) {
        if (islower((unsigned char)*name)) return 0;
        if (isupper((unsigned char)*name)) letters = 1;
    }
    return letters;
}

static void add_pending(const char* name) {
    if (is_macro_like(name)) return;
    add_name(pending, &pending_count, name);
}

static void drop_pending(const char* name) {
    int i, j = 0;
    for (i = 0; i < pending_count; i++) {
        if (strcmp(pending[i], name) != 0) {
            if (i != j) strcpy(pending[j], pending[i]);
            j++;
        }
    }
    pending_count = j;
}

static void flush_pending(void) {
    int i;
    if (SBuf_getLen(caller_function) > 0) {
        for (i = 0; i < pending_count; i++) {
            if (!has_name(scope_names, scope_count, pending[i])) {
                printf("\t\"%s()\" -> \"%s\"\n", SBuf_getText(caller_function), pending[i]);
            }
        }
    }
    pending_count = 0;
}

/* A declaration "type name" ends at '=', ',' or ';': name becomes a local. */
static void commit_declaration(void) {
    const char* t = SBuf_getText(type_buffer);
    char tok[NAME_MAX_LEN];
    int has_type = 0, k = 0;
    for (; ; t++) {
        if (isalnum((unsigned char)*t) || *t == '_') {
            has_type = 1;
            if (k < NAME_MAX_LEN - 1) tok[k++] = *t;
        } else {
            if (k > 0) { tok[k] = '\0'; drop_pending(tok); k = 0; }
            if (*t == '\0') break;
        }
    }
    if (!has_type || SBuf_getLen(word_buffer) == 0) return;
    drop_pending(SBuf_getText(word_buffer));
    add_name(scope_names, &scope_count, SBuf_getText(word_buffer));
}

static void scope_open(int was_top_level) {
    if (inBraceCounter < SCOPE_DEPTH_MAX) scope_marks[inBraceCounter] = scope_count;
    if (was_top_level && in_function_body(inBraceCounter)) {
        int i;
        for (i = 0; i < param_count; i++) add_name(scope_names, &scope_count, param_names[i]);
    }
    param_count = 0;
    head_closed = 0;
}

/* K&R style:  void f(a, b) int a; char *b; { ... }  -- the declared name is a parameter. */
static void knr_param(void) {
    if (head_closed && SBuf_getLen(word_buffer) > 0) {
        add_name(param_names, &param_count, SBuf_getText(word_buffer));
    }
}

/* Call before the depth is decremented. */
static void scope_close(void) {
    if (inBraceCounter < SCOPE_DEPTH_MAX) scope_count = scope_marks[inBraceCounter];
}

/*
 * Read a parameter list (the '(' is already consumed) and remember the
 * parameter names:  f(int a, char *b, void (*cb)(int), int v[])
 * The name is the last identifier of each parameter, or the one in "(*name)".
 */
static void scan_params(void) {
    char cand[NAME_MAX_LEN], word[NAME_MAX_LEN];
    int depth = 1, wlen = 0, c = 0, in_word = 0, star = 0, pushed = -1;
    cand[0] = '\0';
    param_count = 0;
    while (depth > 0 && c != EOF) {
        if (pushed >= 0) { c = pushed; pushed = -1; } else c = input();
        if (c != EOF && (isalnum(c) || c == '_')) {
            if (wlen < NAME_MAX_LEN - 1) word[wlen++] = (char)c;
            in_word = 1;
            continue;
        }
        if (in_word) {
            word[wlen] = '\0';
            if (!isdigit((unsigned char)word[0]) && !is_type_keyword(word)
                && (depth == 1 || (depth == 2 && star))) {
                strcpy(cand, word);
            }
            wlen = in_word = 0;
        }
        if (c == '(') { depth++; star = 0; }
        else if (c == '*') { if (depth == 2) star = 1; }
        else if (c == '[') skip_balanced('[', ']');
        else if (c == '/') {
            /* skip comments; any other char after '/' is read again */
            int n = input(), prev = 0;
            if (n == '*') {
                while ((n = input()) != EOF && !(prev == '*' && n == '/')) prev = n;
            } else if (n == '/') {
                while ((n = input()) != EOF && n != '\n') {}
            } else if (n != EOF) {
                pushed = n;
            }
        }
        else if (c == ')' || c == ',' || c == EOF) {
            if (c == ')') depth--;
            if ((depth == 0 || (c == ',' && depth == 1)) && cand[0]) {
                add_name(param_names, &param_count, cand);
                cand[0] = '\0';
            }
        }
    }
}

static int is_control_keyword(const char* w) {
    static const char* const kw[] = {
        "break", "case", "continue", "default", "do", "else", "for", "goto", "if", "return",
        "switch", "while", "sizeof", NULL
    };
    int i;
    for (i = 0; kw[i]; i++) if (strcmp(kw[i], w) == 0) return 1;
    return 0;
}

static void control_keyword(const char* text) {
    clear_all();
    in_expression_mode = 1;
    if (strcmp(text, "goto") == 0) skip_next_word = 1;
    if (strcmp(text, "for") == 0) for_pending = 1;
}

static void type_keyword(const char* text, int len) {
    if (strcmp(text, "struct") == 0 || strcmp(text, "union") == 0 || strcmp(text, "enum") == 0) {
        top_aggregate_keyword(inBraceCounter);
        if (in_declaration()) decl_aggregate = 1;
    }
    if (in_function_body(inBraceCounter) && !in_expression_mode) {
        SBuf_append(type_buffer, text, len);
    }
}

/*
 * A word followed by '(' or ':' is matched by a rule with trailing context,
 * which beats the keyword rules; those rules hand keywords back here.
 */
static int any_keyword(const char* text, int len) {
    if (is_control_keyword(text)) { control_keyword(text); return 1; }
    if (is_type_keyword(text)) { type_keyword(text, len); return 1; }
    if (strcmp(text, "typedef") == 0) { clear_all(); scan_typedef(); return 1; }
    return 0;
}

/* is_call: the word is followed by '(' (a call, or a declarator head). */
static void on_word(const char* text, int len, int is_call) {
    int body = in_function_body(inBraceCounter);
    /* a known type name starts a declaration, e.g. after "case 1:" */
    if (body && in_expression_mode && SBuf_getLen(word_buffer) == 0
        && SBuf_getLen(type_buffer) == 0 && is_typedef(text)) {
        in_expression_mode = 0;
    }
    if (body) {
        if (after_member) after_member = 0;
        else if (skip_next_word) skip_next_word = 0;
        else if (!is_call) add_pending(text);
        if (!in_expression_mode) {
            if (SBuf_getLen(word_buffer) > 0) {
                SBuf_append(type_buffer, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
            }
            SBuf_setText(word_buffer, text, len);
        }
    } else {
        SBuf_setText(word_buffer, text, len);
    }
}

static void paren_open(void) {
    if (inBraceCounter == 0) {
        if (SBuf_isExist(word_buffer)) {
            SBuf_setText(caller_function, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
        }
        clear_all();
        scan_params();
        top_close_paren(0);
        head_closed = 1;
    } else {
        clear_all();
        /* "for (int i = 0; ...": the init clause may declare a variable */
        in_expression_mode = for_pending ? 0 : 1;
    }
    for_pending = 0;
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

NUMBER ({FLOAT}([eE][+-]?{DIGIT}+)?[fFlLuU]*|0[xX]{HEX}+[uUlL]*)
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
        control_keyword(yytext);
    }

    "typedef" {
        clear_all();
        scan_typedef();
    }

    "char"|"double"|"float"|"int"|"long"|"short"|"signed"|"unsigned"|"void"|"_Bool"|"_Complex"|"struct"|"union"|"enum"|"const"|"volatile"|"restrict"|"static"|"extern"|"register"|"auto"|"inline" {
        type_keyword(yytext, yyleng);
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

    {WORD}/[[:blank:]]*":"[^:] {
        /* a label, or the constant of a "case": not a variable */
        if (any_keyword(yytext, yyleng)) {
            /* "default:" and the like */
        } else if (in_function_body(inBraceCounter) && pending_count == 0
            && SBuf_getLen(word_buffer) == 0 && SBuf_getLen(type_buffer) == 0) {
            in_expression_mode = 1;
        } else {
            on_word(yytext, yyleng, 0);
        }
    }

    {WORD}/[[:space:]]*"(" {
        if (!any_keyword(yytext, yyleng)) on_word(yytext, yyleng, 1);
    }

    {WORD} {
        on_word(yytext, yyleng, 0);
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
            int was_top_level = inBraceCounter == 0;
            if (in_function_body(inBraceCounter)) flush_pending();
            top_open_brace(inBraceCounter);
            inBraceCounter++;
            scope_open(was_top_level);
            clear_all();
        }
    }

    "}"|"%>" {
        int was_open = inBraceCounter > 0;
        if (in_function_body(inBraceCounter)) flush_pending();
        if (was_open) { scope_close(); inBraceCounter--; }
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
            commit_declaration();
        }
        SBuf_init(word_buffer);
        in_expression_mode = 1;
    }

    "," {
        if (inBraceCounter == 0) knr_param();
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            commit_declaration();
        }
        SBuf_init(word_buffer);
        in_expression_mode = 0;
    }

    ";" {
        top_semicolon(inBraceCounter);
        if (in_function_body(inBraceCounter) && !in_expression_mode) {
            commit_declaration();
        }
        if (in_function_body(inBraceCounter)) flush_pending();
        else if (head_closed && SBuf_getLen(word_buffer) > 0) knr_param();
        else { param_count = 0; head_closed = 0; }
        clear_all();
    }

    "..."|">>="|"<<="|"+="|"-="|"*="|"/="|"%="|"&="|"^="|"|="|">>"|"<<"|"++"|"--"|"&&"|"||"|"<="|">="|"=="|"!=" {
        clear_all();
        if (inBraceCounter > 0) {
            in_expression_mode = 1;
        }
    }

    "->" {
        clear_all();
        if (inBraceCounter > 0) in_expression_mode = 1;
        if (in_function_body(inBraceCounter)) after_member = 1;
    }

    "." {
        SBuf_init(word_buffer);
        if (in_function_body(inBraceCounter)) after_member = 1;
    }

    "["|"<:" {
        if ((in_declaration() || (inBraceCounter == 0 && head_closed)) && SBuf_getLen(word_buffer) > 0) {
            skip_balanced('[', ']');
        } else {
            SBuf_init(word_buffer);
        }
    }

    "]"|":>"|"&"|"!"|"~"|"+"|"-"|"/"|"%"|"<"|">"|"^"|"|"|"?"|":" {
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
