void (*gfp)(int);
int garr[4];
void f(int n) {
    int m[2][3], k;
    char buf[N + 1] = "x";
    int v[2] = {1, 2};
    struct S { int a; } s, *ps;
    enum { A, B } e;
    union U { int i; float f; };
    MyType (*cb)(int, char *);
    const char *(*names)(void);
    int (*fp)(int) = 0;
    m[0][1] = 3;
    k = m[1][2];
    (*fp)(k);
    foo(*ps);
    g(arr[1]);
}
