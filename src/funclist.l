%{
#include <stdio.h>
#include <stdlib.h>

#include "SBuf.h"

int inBraceCounter = 0;

SBuf* func_buf;
SBuf* from_func;

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
WSPACE [[:blank]]+
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
    {NUMBER} { SBuf_init(func_buf); }
    {WSPACE} { }
    {COMMENTS} { SBuf_init(func_buf); BEGIN(COMMENT_SA); }
    {COMMENT}  { SBuf_init(func_buf); BEGIN(COMMENT_SS); }
    \" { SBuf_init(func_buf); BEGIN(STRING_ST); }
    \' { SBuf_init(func_buf); BEGIN(STRING_SS); }
    {PRICOMPILE} { BEGIN(PRICOMPILER); }

    "auto"       { SBuf_init(func_buf); }
    "_Bool"      { SBuf_init(func_buf); }
    "break"      { SBuf_init(func_buf); }
    "case"       { SBuf_init(func_buf); }
    "char"       { SBuf_init(func_buf); }
    "_Complex"   { SBuf_init(func_buf); }
    "const"      { SBuf_init(func_buf); }
    "continue"   { SBuf_init(func_buf); }
    "default"    { SBuf_init(func_buf); }
    "do"         { SBuf_init(func_buf); }
    "double"     { SBuf_init(func_buf); }
    "else"       { SBuf_init(func_buf); }
    "enum"       { SBuf_init(func_buf); }
    "extern"     { SBuf_init(func_buf); }
    "float"      { SBuf_init(func_buf); }
    "for"        { SBuf_init(func_buf); }
    "goto"       { SBuf_init(func_buf); }
    "if"         { SBuf_init(func_buf); }
    "_Imaginary" { SBuf_init(func_buf); }
    "inline"     { SBuf_init(func_buf); }
    "int"        { SBuf_init(func_buf); }
    "long"       { SBuf_init(func_buf); }
    "register"   { SBuf_init(func_buf); }
    "restrict"   { SBuf_init(func_buf); }
    "return"     { SBuf_init(func_buf); }
    "short"      { SBuf_init(func_buf); }
    "signed"     { SBuf_init(func_buf); }
    "sizeof"     { SBuf_init(func_buf); }
    "static"     { SBuf_init(func_buf); }
    "struct"     { SBuf_init(func_buf); }
    "switch"     { SBuf_init(func_buf); }
    "typedef"    { SBuf_init(func_buf); }
    "union"      { SBuf_init(func_buf); }
    "unsigned"   { SBuf_init(func_buf); }
    "void"       { SBuf_init(func_buf); }
    "volatile"   { SBuf_init(func_buf); }
    "while"      { SBuf_init(func_buf); }

    {WORD} {
        SBuf_setText(func_buf, yytext, yyleng);
    }
    \(  {
        if (SBuf_isExist(func_buf)) {
            if (inBraceCounter == 0) {
                SBuf_setText(from_func, SBuf_getText(func_buf), SBuf_getLen(func_buf));
            }
        }
        SBuf_init(func_buf);
    }

    "..." { SBuf_init(func_buf); }
    ">>=" { SBuf_init(func_buf); }
    "<<=" { SBuf_init(func_buf); }
    "+="  { SBuf_init(func_buf); }
    "-="  { SBuf_init(func_buf); }
    "*="  { SBuf_init(func_buf); }
    "/="  { SBuf_init(func_buf); }
    "%="  { SBuf_init(func_buf); }
    "&="  { SBuf_init(func_buf); }
    "^="  { SBuf_init(func_buf); }
    "|="  { SBuf_init(func_buf); }
    ">>"  { SBuf_init(func_buf); }
    "<<"  { SBuf_init(func_buf); }
    "++"  { SBuf_init(func_buf); }
    "--"  { SBuf_init(func_buf); }
    "->"  { SBuf_init(func_buf); }
    "&&"  { SBuf_init(func_buf); }
    "||"  { SBuf_init(func_buf); }
    "<="  { SBuf_init(func_buf); }
    ">="  { SBuf_init(func_buf); }
    "=="  { SBuf_init(func_buf); }
    "!="  { SBuf_init(func_buf); }
    ";"   { SBuf_init(func_buf); }
    ("{"|"<%")  {
        inBraceCounter++; SBuf_init(func_buf);
    }
    ("}"|"%>")  {
        inBraceCounter--; SBuf_init(func_buf);
        if (inBraceCounter == 0) {
            if ( SBuf_getLen(from_func) ) {
                printf("%s\n", SBuf_getText(from_func));
            }
        }
    }
    ","   { SBuf_init(func_buf); }
    ":"   { SBuf_init(func_buf); }
    "="   { SBuf_init(func_buf); }
    ")"   { SBuf_init(func_buf); }
    ("["|"<:")  { SBuf_init(func_buf); }
    ("]"|":>")  { SBuf_init(func_buf); }
    "."   { SBuf_init(func_buf); }
    "&"   { SBuf_init(func_buf); }
    "!"   { SBuf_init(func_buf); }
    "~"   { SBuf_init(func_buf); }
    "-"   { SBuf_init(func_buf); }
    "+"   { SBuf_init(func_buf); }
    "*"   { SBuf_init(func_buf); }
    "/"   { SBuf_init(func_buf); }
    "%"   { SBuf_init(func_buf); }
    "<"   { SBuf_init(func_buf); }
    ">"   { SBuf_init(func_buf); }
    "^"   { SBuf_init(func_buf); }
    "|"   { SBuf_init(func_buf); }
    "?"   { SBuf_init(func_buf); }

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
