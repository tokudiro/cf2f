#ifdef __cplusplus
extern "C" {
#endif
void f() { g(); }
extern "C" int h(void);
void k() { h(); _m(1); }
#ifdef __cplusplus
}
#endif
