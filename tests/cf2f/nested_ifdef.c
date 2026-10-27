#ifdef A
#ifdef B
void f(void) {
#else
void f(int a) {
#endif
#else
void f(long l) {
#endif
  g();
}
void h() { k(); }
