// Runs the project binary ($TEST_BIN) like a user would
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#include "cum.h"

DECLARE_COMMAND_RUN()

static int
run(const char *bin, const char *arg)
{
        Command cmd = { 0 };
        Command_add(&cmd, bin, arg);
        int status = Command_run(cmd);
        Command_destroy(&cmd);
        return status;
}

int
main(void)
{
        const char *bin = getenv("TEST_BIN");
        if (bin == NULL) return 1;

        if (run(bin, "--version") != 0) return 1;
        if (run(bin, "--help") != 0) return 1;
        if (run(bin, "--no-such-flag") == 0) return 1; // must fail
        if (run(bin, "--config=/nonexistent.lua") == 0) return 1;
        return 0;
}
