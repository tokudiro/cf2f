int main(int argc, char **argv) {
    if (argc > 1) { helper(argv[1]); }
    while (cond()) { step(); }
    for (i = 0; i < n; i++) { work(i); }
    return compute(1) + other(2);
}
static int helper(char *s) { printf("call fake(x) %s", s); return 0; }
