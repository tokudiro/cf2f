#include <stdio.h>
#include "SBuf_define.h"
#include "SBuf.h"

extern SBuf* func_buf;
extern SBuf* from_func;

/* flex extern */
extern FILE *yyin;
extern int yylex (void);

int main(int argc, char** argv)
{
    SBuf a_func_buf;
    func_buf = SBuf_init(&a_func_buf);

    SBuf a_from_func;
    from_func = SBuf_init(&a_from_func);

    SBuf_init(func_buf);
    SBuf_init(from_func);

    if(argc > 1) {
        yyin = fopen(argv[1], "r");
    }

    if ( yyin != 0) {
        return yylex();
    }
    return 0;
}

