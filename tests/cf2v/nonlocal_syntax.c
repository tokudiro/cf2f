void f() {
    struct S s;
    s.a = p->b + q.c;
    x = a < b ? c : d;
    y = (T)z;
    w = MAX_SIZE + sizeof(buf) + 1.5f + 0x10 + 2e3;
    puts("not_a_var");
    c = 'z';
    for (;;) { if (done) break; }
    switch (mode) { case A: m1 = 1; break; default: m2 = 2; }
    goto out;
out:
    return;
}
