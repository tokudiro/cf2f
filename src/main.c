#include <stdio.h>
#include "SBuf_define.h"
#include "SBuf.h"

extern SBuf* word_buffer;
extern SBuf* caller_function;

/* flex extern */
extern FILE *yyin;
extern int yylex (void);

int main(int argc, char** argv)
{
    SBuf a_func_buf;
    word_buffer = SBuf_init(&a_func_buf);

    SBuf a_from_func;
    caller_function = SBuf_init(&a_from_func);

    SBuf_init(word_buffer);
    SBuf_init(caller_function);

    if(argc > 1) {
        yyin = fopen(argv[1], "r");
    }

    if ( yyin != 0) {
        return yylex();
    }
    return 0;
}

