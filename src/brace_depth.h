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

/*
 * Tell function bodies from other top-level brace blocks (struct/union/enum
 * definitions, "= { ... }" initializers), so that only a function body prints
 * the caller_function when its closing '}' is reached.
 */
static int top_aggregate = 0;   /* struct/union/enum seen in this top-level declaration */
static int top_assign = 0;      /* '=' seen in this top-level declaration */
static int top_is_function = 0; /* the open top-level block is a function body */

static int top_extern_seen = 0; /* 'extern' seen in this top-level declaration */
static int top_extern_c = 0;    /* ... followed by a string: extern "C" */

static void top_extern_keyword(int depth) { if (depth == 0) top_extern_seen = 1; }
static void top_string_start(int depth) { if (depth == 0 && top_extern_seen) top_extern_c = 1; }
static void top_aggregate_keyword(int depth) { if (depth == 0) top_aggregate = 1; }
static void top_close_paren(int depth) { if (depth == 0) top_aggregate = 0; }
static void top_assign_op(int depth) { if (depth == 0) { top_assign = 1; top_extern_seen = top_extern_c = 0; } }
static void top_semicolon(int depth) { if (depth == 0) top_aggregate = top_assign = top_extern_seen = top_extern_c = 0; }

/*
 * Call on '{', before incrementing the depth; increment only if it returns 0.
 * The '{' of  extern "C" {  opens a linkage block, not a function body or an
 * aggregate; its '}' is often in a different #ifdef, so it is not counted.
 */
static int top_open_brace(int depth)
{
    if (depth == 0 && top_extern_c) {
        top_extern_seen = top_extern_c = 0;
        return 1;
    }
    if (depth == 0) top_is_function = !(top_aggregate || top_assign);
    return 0;
}

/* Inside a function body (not in a struct/union/enum definition or initializer). */
static int in_function_body(int depth) { return depth > 0 && top_is_function; }

/* Call when '}' brings the depth back to 0; returns 1 for a function body. */
static int top_close_brace_is_function(void)
{
    int r = top_is_function;
    top_aggregate = top_assign = top_is_function = 0;
    return r;
}

#endif // BRACE_DEPTH_H
