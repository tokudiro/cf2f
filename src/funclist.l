%{
#include <stdio.h>
#include <stdlib.h>

#include "SBuf.h"
#include "brace_depth.h"

int inBraceCounter = 0;

SBuf* word_buffer;
SBuf* caller_function;

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
    {NUMBER} { SBuf_init(word_buffer); }
    {WSPACE} { }
    {COMMENTS} { SBuf_init(word_buffer); BEGIN(COMMENT_SA); }
    {COMMENT}  { SBuf_init(word_buffer); BEGIN(COMMENT_SS); }
    \" { SBuf_init(word_buffer); BEGIN(STRING_ST); }
    \' { SBuf_init(word_buffer); BEGIN(STRING_SS); }
    {PRICOMPILE} { brace_depth_directive(yytext, &inBraceCounter); BEGIN(PRICOMPILER); }

    "auto"       { SBuf_init(word_buffer); }
    "_Bool"      { SBuf_init(word_buffer); }
    "break"      { SBuf_init(word_buffer); }
    "case"       { SBuf_init(word_buffer); }
    "char"       { SBuf_init(word_buffer); }
    "_Complex"   { SBuf_init(word_buffer); }
    "const"      { SBuf_init(word_buffer); }
    "continue"   { SBuf_init(word_buffer); }
    "default"    { SBuf_init(word_buffer); }
    "do"         { SBuf_init(word_buffer); }
    "double"     { SBuf_init(word_buffer); }
    "else"       { SBuf_init(word_buffer); }
    "enum"       { top_aggregate_keyword(inBraceCounter); SBuf_init(word_buffer); }
    "extern"     { SBuf_init(word_buffer); }
    "float"      { SBuf_init(word_buffer); }
    "for"        { SBuf_init(word_buffer); }
    "goto"       { SBuf_init(word_buffer); }
    "if"         { SBuf_init(word_buffer); }
    "_Imaginary" { SBuf_init(word_buffer); }
    "inline"     { SBuf_init(word_buffer); }
    "int"        { SBuf_init(word_buffer); }
    "long"       { SBuf_init(word_buffer); }
    "register"   { SBuf_init(word_buffer); }
    "restrict"   { SBuf_init(word_buffer); }
    "return"     { SBuf_init(word_buffer); }
    "short"      { SBuf_init(word_buffer); }
    "signed"     { SBuf_init(word_buffer); }
    "sizeof"     { SBuf_init(word_buffer); }
    "static"     { SBuf_init(word_buffer); }
    "struct"     { top_aggregate_keyword(inBraceCounter); SBuf_init(word_buffer); }
    "switch"     { SBuf_init(word_buffer); }
    "typedef"    { SBuf_init(word_buffer); }
    "union"      { top_aggregate_keyword(inBraceCounter); SBuf_init(word_buffer); }
    "unsigned"   { SBuf_init(word_buffer); }
    "void"       { SBuf_init(word_buffer); }
    "volatile"   { SBuf_init(word_buffer); }
    "while"      { SBuf_init(word_buffer); }

    {WORD} {
        SBuf_setText(word_buffer, yytext, yyleng);
    }
    \(  {
        if (SBuf_isExist(word_buffer)) {
            if (inBraceCounter == 0) {
                SBuf_setText(caller_function, SBuf_getText(word_buffer), SBuf_getLen(word_buffer));
            }
        }
        SBuf_init(word_buffer);
    }

    "..." { SBuf_init(word_buffer); }
    ">>=" { SBuf_init(word_buffer); }
    "<<=" { SBuf_init(word_buffer); }
    "+="  { SBuf_init(word_buffer); }
    "-="  { SBuf_init(word_buffer); }
    "*="  { SBuf_init(word_buffer); }
    "/="  { SBuf_init(word_buffer); }
    "%="  { SBuf_init(word_buffer); }
    "&="  { SBuf_init(word_buffer); }
    "^="  { SBuf_init(word_buffer); }
    "|="  { SBuf_init(word_buffer); }
    ">>"  { SBuf_init(word_buffer); }
    "<<"  { SBuf_init(word_buffer); }
    "++"  { SBuf_init(word_buffer); }
    "--"  { SBuf_init(word_buffer); }
    "->"  { SBuf_init(word_buffer); }
    "&&"  { SBuf_init(word_buffer); }
    "||"  { SBuf_init(word_buffer); }
    "<="  { SBuf_init(word_buffer); }
    ">="  { SBuf_init(word_buffer); }
    "=="  { SBuf_init(word_buffer); }
    "!="  { SBuf_init(word_buffer); }
    ";"   { top_semicolon(inBraceCounter); SBuf_init(word_buffer); }
    ("{"|"<%")  {
        top_open_brace(inBraceCounter); inBraceCounter++; SBuf_init(word_buffer);
    }
    ("}"|"%>")  {
        int was_open = inBraceCounter > 0; if (was_open) inBraceCounter--; SBuf_init(word_buffer);
        if (was_open && inBraceCounter == 0) {
            if ( top_close_brace_is_function() && SBuf_getLen(caller_function) ) {
                printf("%s\n", SBuf_getText(caller_function));
            }
        }
    }
    ","   { SBuf_init(word_buffer); }
    ":"   { SBuf_init(word_buffer); }
    "="   { top_assign_op(inBraceCounter); SBuf_init(word_buffer); }
    ")"   { top_close_paren(inBraceCounter); SBuf_init(word_buffer); }
    ("["|"<:")  { SBuf_init(word_buffer); }
    ("]"|":>")  { SBuf_init(word_buffer); }
    "."   { SBuf_init(word_buffer); }
    "&"   { SBuf_init(word_buffer); }
    "!"   { SBuf_init(word_buffer); }
    "~"   { SBuf_init(word_buffer); }
    "-"   { SBuf_init(word_buffer); }
    "+"   { SBuf_init(word_buffer); }
    "*"   { SBuf_init(word_buffer); }
    "/"   { SBuf_init(word_buffer); }
    "%"   { SBuf_init(word_buffer); }
    "<"   { SBuf_init(word_buffer); }
    ">"   { SBuf_init(word_buffer); }
    "^"   { SBuf_init(word_buffer); }
    "|"   { SBuf_init(word_buffer); }
    "?"   { SBuf_init(word_buffer); }

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
