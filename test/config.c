// The example config.lua (tests run from the project root) has what main.c
// expects
#include <stdio.h>
#include <string.h>

#include "lua_compat.h" // before conf.h

#define INCLUDE_CONF_IMPLEMENTATION
#include "conf.h"

#define CHECK(x)                                                   \
        if (!(x)) {                                                \
                fprintf(stderr, "%d: failed: %s\n", __LINE__, #x); \
                return 1;                                          \
        }

int
main(void)
{
        Conf conf;
        const char *str;
        int n;

        CHECK(Conf_open(&conf, "config.lua") == CONF_OK);
        CHECK(Conf_get_str(conf, &str, "Config.greeting") == CONF_OK);
        CHECK(Conf_get_int(conf, &n, "Config.times") == CONF_OK && n >= 0);
        CHECK(Conf_get_len(conf, &n, "Config.names") == CONF_OK && n > 0);
        CHECK(Conf_get_str(conf, &str, "Config.names.1") == CONF_OK);
        CHECK(Conf_get_str(conf, &str, "Config.missing") == CONF_UNDEF);
        Conf_close(conf);
        return 0;
}
