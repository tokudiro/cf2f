%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "SBuf.h"
#include "brace_depth.h"
#include "SBuf_define.h"

int inBraceCounter = 0;
int in_expression_mode = 0;

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

    "break"|"case"|"continue"|"default"|"do"|"else"|"for"|"goto"|"if"|"return"|"switch"|"while"|"sizeof"|"typedef" {
        clear_all();
        in_expression_mode = 1;
    }

    "char"|"double"|"float"|"int"|"long"|"short"|"signed"|"unsigned"|"void"|"_Bool"|"_Complex"|"struct"|"union"|"enum"|"const"|"volatile"|"restrict"|"static"|"extern"|"register"|"auto"|"inline" {
        if (strcmp(yytext, "struct") == 0 || strcmp(yytext, "union") == 0 || strcmp(yytext, "enum") == 0) {
            top_aggregate_keyword(inBraceCounter);
        }
        if (inBraceCounter > 0 && !in_expression_mode) {
            SBuf_append(type_buffer, yytext, yyleng);
        }
    }

    "*" {
        if (inBraceCounter > 0 && !in_expression_mode) {
            if (SBuf_getLen(word_buffer) > 0) {
                SBuf_append(type_buffer, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
                SBuf_init(word_buffer);
            }
            SBuf_append(type_buffer, "*", 1);
        }
    }

    {WORD} {
        if (inBraceCounter > 0) {
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

    "(" {
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

    ")" {
        top_close_paren(inBraceCounter);
        SBuf_init(word_buffer);
    }

    "{"|"<%" {
        top_open_brace(inBraceCounter);
        inBraceCounter++;
        clear_all();
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
        if (inBraceCounter > 0 && !in_expression_mode) {
            if (SBuf_getLen(type_buffer) > 0 && SBuf_getLen(word_buffer) > 0) {
                printf("\t\"%s()\" -> \"%s %s\"\n", SBuf_getText(caller_function), SBuf_getText(type_buffer), SBuf_getText(word_buffer));
            }
        }
        SBuf_init(word_buffer);
        in_expression_mode = 1;
    }

    "," {
        if (inBraceCounter > 0 && !in_expression_mode) {
            if (SBuf_getLen(type_buffer) > 0 && SBuf_getLen(word_buffer) > 0) {
                printf("\t\"%s()\" -> \"%s %s\"\n", SBuf_getText(caller_function), SBuf_getText(type_buffer), SBuf_getText(word_buffer));
            }
        }
        SBuf_init(word_buffer);
        in_expression_mode = 0;
    }

    ";" {
        top_semicolon(inBraceCounter);
        if (inBraceCounter > 0 && !in_expression_mode) {
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

    "["|"<:"|"]"|":>"|"."|"&"|"!"|"~"|"+"|"-"|"/"|"%"|"<"|">"|"^"|"|"|"?"|":" {
        SBuf_init(word_buffer);
    }

    \n { }
    .  { }
}

<PRICOMPILER>{
    \n { BEGIN(INITIAL); }
    . { }
}

<COMMENT_SA>{
    {COMMENTE} { BEGIN(INITIAL); }
    \n { }
    . { }
}

<COMMENT_SS>{
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
