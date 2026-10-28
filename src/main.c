#include <stdio.h>
#include "SBuf_define.h"
#include "SBuf.h"

extern SBuf* word_buffer;
extern SBuf* caller_function;

#ifdef USE_TYPE_BUFFER
extern SBuf* type_buffer;
#endif // USE_TYPE_BUFFER

/* flex extern */
extern FILE *yyin;
extern int yylex (void);

int main(int argc, char** argv)
{
    SBuf a_word_buffer;
    word_buffer = SBuf_init(&a_word_buffer);
    //SBuf_init(word_buffer);

    SBuf a_caller_function;
    caller_function = SBuf_init(&a_caller_function);
    //SBuf_init(caller_function);

#ifdef USE_TYPE_BUFFER
    SBuf a_type_buffer;
    type_buffer = SBuf_init(&a_type_buffer);
    //SBuf_init(type_buffer);
#endif // USE_TYPE_BUFFER

    yyin = stdin;
    if(argc > 1) {
        yyin = fopen(argv[1], "r");
        if(yyin == NULL) {
            perror(argv[1]);
            return 1;
        }
    }

    return yylex();
}

