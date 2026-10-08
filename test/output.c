// What the project binary ($TEST_BIN) prints, for a config and without one
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CHECK(x)                                                   \
        if (!(x)) {                                                \
                fprintf(stderr, "%d: failed: %s\n", __LINE__, #x); \
                return 1;                                          \
        }

static char dir[] = "/tmp/test-output-XXXXXX";
static char bin[PATH_MAX];

// Run "BIN ARGS" with HOME and XDG_CONFIG_HOME in an empty dir, from it, so no
// config is found but the one given. Its stdout goes in OUT. Returns its exit
// status, or -1.
static int
run(const char *args, char *out, size_t size)
{
        char cmd[2 * PATH_MAX];
        size_t len;
        FILE *p;

        snprintf(cmd, sizeof cmd, "cd '%s' && HOME='%s' XDG_CONFIG_HOME='%s' '%s' %s", dir, dir, dir, bin, args);
        if ((p = popen(cmd, "r")) == NULL) return -1;
        len = fread(out, 1, size - 1, p);
        out[len] = '\0';
        return pclose(p);
}

static int
write_file(const char *name, const char *text)
{
        char path[PATH_MAX];
        FILE *f;

        snprintf(path, sizeof path, "%s/%s", dir, name);
        if ((f = fopen(path, "w")) == NULL) return 1;
        fputs(text, f);
        return fclose(f) != 0;
}

static int
check(void)
{
        char out[4096];

        // Every name, `times` times
        CHECK(write_file("all.lua", "Config = { greeting = 'Hi', times = 2, names = { 'a', 'b' } }") == 0);
        CHECK(run("--config all.lua", out, sizeof out) == 0);
        CHECK(strcmp(out, "Hi, a!\nHi, b!\nHi, a!\nHi, b!\n") == 0);

        // What's missing keeps its default
        CHECK(write_file("some.lua", "Config = { greeting = 'Yo' }") == 0);
        CHECK(run("-c some.lua", out, sizeof out) == 0);
        CHECK(strcmp(out, "Yo, world!\n") == 0);

        // No config anywhere
        CHECK(run("", out, sizeof out) == 0);
        CHECK(strcmp(out, "Hello, world!\n") == 0);

        // A broken config is an error, and nothing is greeted
        CHECK(write_file("broken.lua", "Config = {") == 0);
        CHECK(run("--config broken.lua 2>/dev/null", out, sizeof out) != 0);
        CHECK(strcmp(out, "") == 0);

        // One line: the name, a space and the version
        CHECK(run("--version", out, sizeof out) == 0);
        CHECK(strchr(out, ' ') != NULL && strchr(out, '\n') == out + strlen(out) - 1);
        return 0;
}

int
main(void)
{
        const char *test_bin = getenv("TEST_BIN");
        char cmd[PATH_MAX + 16];
        int failed;

        if (test_bin == NULL || realpath(test_bin, bin) == NULL) return 1;
        if (mkdtemp(dir) == NULL) return 1;
        failed = check();
        snprintf(cmd, sizeof cmd, "rm -rf '%s'", dir);
        if (system(cmd) != 0) return 1;
        return failed;
}
