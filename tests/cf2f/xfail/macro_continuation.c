void f() { g(); }
#define BLOCK(x) \
  do { foo(x); } while (0)
void h() { k(); }
