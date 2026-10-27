#ifndef BRACE_DEPTH_H
#define BRACE_DEPTH_H

#include <string.h>

#define COND_STACK_MAX 64

/* Brace depth at each open #if/#ifdef/#ifndef. */
static int cond_stack[COND_STACK_MAX];
static int cond_top = 0;

/*
 * Keep the brace depth consistent across preprocessor branches:
 * every #else/#elif branch starts from the depth seen at its #if,
 * so alternative function heads such as
 *     #ifdef X
 *     void f(int a) {
 *     #else
 *     void f(void) {
 *     #endif
 * count as one '{'.
 */
static void brace_depth_directive(const char* text, int* depth)
{
    if (strcmp(text, "#if") == 0 || strcmp(text, "#ifdef") == 0 || strcmp(text, "#ifndef") == 0) {
        if (cond_top < COND_STACK_MAX) cond_stack[cond_top] = *depth;
        cond_top++;
    } else if (strcmp(text, "#else") == 0 || strcmp(text, "#elif") == 0) {
        if (cond_top > 0 && cond_top <= COND_STACK_MAX) *depth = cond_stack[cond_top - 1];
    } else if (strcmp(text, "#endif") == 0) {
        if (cond_top > 0) cond_top--;
    }
}

#endif // BRACE_DEPTH_H
