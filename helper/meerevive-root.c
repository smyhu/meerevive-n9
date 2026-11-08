/* meerevive-root - root helper of the MeeRevive app (Nokia N9, Harmattan PR1.3).
 *
 * The package gives this one binary the Aegis credentials CAP::setuid and
 * CAP::setgid, so it can switch to root when the app (user) starts it.
 * It then runs ONLY the MeeRevive engine, /opt/meerevive-n9/engine.sh, and
 * ONLY with the engine's own commands:
 *     list | check | log | version | tls-finish | backup | restore | reboot
 *     install <id>... | remove <id>...     (id = a-z 0-9 '-', or "all" for install)
 * Anything else is refused. The engine starts with a fixed, clean environment
 * (no LD_PRELOAD, no PATH tricks from the caller), in "/", with umask 022.
 *
 * No libc: raw ARM EABI syscalls, so the static binary runs on the N9 kernel
 * (2.6.32) whatever the build host's glibc is.
 * Designed and written by Claude (Anthropic) together with smyhu for Nokia N9. MIT licence. */

static long sc1(long n, long a) { register long r7 asm("r7") = n; register long r0 asm("r0") = a;
    asm volatile("svc 0" : "+r"(r0) : "r"(r7) : "memory"); return r0; }
static long sc3(long n, long a, long b, long c) { register long r7 asm("r7") = n; register long r0 asm("r0") = a;
    register long r1 asm("r1") = b; register long r2 asm("r2") = c;
    asm volatile("svc 0" : "+r"(r0) : "r"(r7), "r"(r1), "r"(r2) : "memory"); return r0; }
#define SYS_exit 1
#define SYS_write 4
#define SYS_execve 11
#define SYS_chdir 12
#define SYS_umask 60
#define SYS_setgroups32 206
#define SYS_setuid32 213
#define SYS_setgid32 214

#define ENGINE "/opt/meerevive-n9/engine.sh"
#define MAXIDS 40
#define MAXIDLEN 40

static int len(const char *s) { int n = 0; while (s[n]) n++; return n; }
static int eq(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *a == *b; }
static void err(const char *s) { sc3(SYS_write, 2, (long)s, len(s)); }
static void die(const char *s, int code) { err("meerevive-root: "); err(s); err("\n"); sc1(SYS_exit, code); }

static int valid_id(const char *s) {
    int n = len(s);
    if (n < 1 || n > MAXIDLEN || s[0] == '-') return 0;
    for (int i = 0; i < n; i++) {
        char c = s[i];
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')) return 0;
    }
    return 1;
}

static const char *plain_cmds[] = { "list", "check", "log", "version", "tls-finish",
                                    "backup", "restore", "reboot", 0 };

void cmain(long *sp) {
    int argc = (int)sp[0];
    char **argv = (char **)(sp + 1);
    if (argc < 2) die("usage: meerevive-root <engine command> [component ids]", 64);

    const char *cmd = argv[1];
    int ok = 0;
    for (int i = 0; plain_cmds[i]; i++) if (eq(cmd, plain_cmds[i])) ok = 1;
    if (ok) {
        if (argc != 2) die("this command takes no arguments", 64);
    } else if (eq(cmd, "install") || eq(cmd, "remove")) {
        if (argc < 3) die("give component ids", 64);
        if (argc - 2 > MAXIDS) die("too many component ids", 64);
        for (int i = 2; i < argc; i++) {
            if (eq(argv[i], "all") && eq(cmd, "install") && argc == 3) continue;
            if (!valid_id(argv[i])) die("invalid component id", 64);
        }
    } else {
        die("command not allowed", 64);
    }

    long g = 0;
    if (sc3(SYS_setgroups32, 1, (long)&g, 0) != 0 || sc1(SYS_setgid32, 0) != 0 || sc1(SYS_setuid32, 0) != 0)
        die("cannot switch to root (Aegis credentials missing - reinstall meerevive-n9 with aegis-dpkg)", 77);
    sc1(SYS_umask, 022);
    sc1(SYS_chdir, (long)"/");

    char *nargv[MAXIDS + 4];
    int k = 0;
    nargv[k++] = "/bin/sh";
    nargv[k++] = ENGINE;
    for (int i = 1; i < argc; i++) nargv[k++] = argv[i];
    nargv[k] = 0;
    char *envp[] = { "PATH=/usr/sbin:/usr/bin:/sbin:/bin", "HOME=/root", "USER=root",
                     "LOGNAME=root", "SHELL=/bin/sh", "TERM=dumb", "MEEREVIVE_APP=1", 0 };
    sc3(SYS_execve, (long)nargv[0], (long)nargv, (long)envp);
    die("cannot start the engine", 126);
}
asm(".text\n.global _start\n_start:\n mov r0, sp\n bl cmain\n");
