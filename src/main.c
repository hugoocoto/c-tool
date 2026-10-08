// __NAME__ - greet everyone listed in a Lua config
// Copyright (C) 2026 Hugo Coto Florez
// SPDX-License-Identifier: GPL-3.0-or-later

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "lua_compat.h" // before conf.h

#define INCLUDE_CONF_IMPLEMENTATION
#include "conf.h"
#include "cum.h"
#include "flag.h"

// Both come from the Makefile: NAME from the project, VERSION from git
#ifndef NAME
#define NAME "__NAME__"
#endif
#ifndef VERSION
#define VERSION "unknown"
#endif

typedef struct {
        char *greeting;
        int times;
        Da(char *) names;
} Config;

static void
config_free(Config *config)
{
        free(config->greeting);
        Da_foreach(name, config->names) free(*name);
        Da_destroy(&config->names);
}

// Returns the user's config file, $XDG_CONFIG_HOME/NAME/config.lua (default
// ~/.config/NAME/config.lua), or NULL if it doesn't exist. Never one in the
// current dir: the config is Lua with its whole standard library, so running
// the program inside a downloaded dir would run that dir's code. The result
// must be freed.
static char *
find_config(void)
{
        char path[4096];
        const char *xdg = getenv("XDG_CONFIG_HOME");
        const char *home = getenv("HOME");

        if (xdg && *xdg)
                snprintf(path, sizeof path, "%s/" NAME "/config.lua", xdg);
        else if (home && *home)
                snprintf(path, sizeof path, "%s/.config/" NAME "/config.lua", home);
        else
                path[0] = '\0';

        if (*path && access(path, R_OK) == 0) return strdup(path);
        return NULL;
}

// Fill CONFIG from PATH, or from find_config() if PATH is NULL. Keys missing
// from the file keep their defaults, and no file at all is not an error.
// Returns 0 on success.
static int
load_config(Config *config, const char *path)
{
        Conf conf = NULL;
        char *found = NULL;
        const char *str;
        int len;

        *config = (Config) { .greeting = strdup("Hello"), .times = 1 };

        if (path == NULL && (path = found = find_config()) == NULL) {
                Da_append(&config->names, strdup("world"));
                return 0;
        }

        if (Conf_open(&conf, path) != CONF_OK) {
                fprintf(stderr, NAME ": can't load %s\n", path);
                free(found);
                return 1;
        }

        // Strings belong to Lua and die with the next Conf_* call: copy them
        if (Conf_get_str(conf, &str, "Config.greeting") == CONF_OK) {
                free(config->greeting);
                config->greeting = strdup(str);
        }
        Conf_get_int(conf, &config->times, "Config.times");
        if (Conf_get_len(conf, &len, "Config.names") == CONF_OK) {
                for (int i = 1; i <= len; i++) // Lua lists start at 1
                        if (Conf_get_str(conf, &str, "Config.names.%d", i) == CONF_OK)
                                Da_append(&config->names, strdup(str));
        }
        if (config->names.count == 0) Da_append(&config->names, strdup("world"));

        Conf_close(conf);
        free(found);
        return 0;
}

int
main(int argc, char **argv)
{
        const char *show_version;
        const char *config_path;
        Config config;

        flag_program(.help = "Greet everyone listed in a Lua config");
        flag_add(&show_version, "--version", "-v", .help = "Show version and exit");
        flag_add(&config_path, "--config", "-c", .nargs = 1, .help = "Use this config file");

        if (flag_parse(&argc, &argv) || argc > 1) {
                flag_show_help(STDERR_FILENO);
                flag_free();
                return 1;
        }

        if (show_version) {
                printf(NAME " %s\n", VERSION);
                flag_free();
                return 0;
        }

        if (load_config(&config, config_path)) {
                config_free(&config);
                flag_free();
                return 1;
        }

        for (int i = 0; i < config.times; i++)
                Da_foreach(name, config.names) printf("%s, %s!\n", config.greeting, *name);

        config_free(&config);
        flag_free();
        return 0;
}
