#ifdef X
void f(int a) {
#else
void f(void) {
#endif
  g();
}
void h() { k(); }
