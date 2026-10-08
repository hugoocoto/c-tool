# Project name: the binary, ~/.config/$(NAME)/, the man page, the AppImage
# and the release assets. The description is for the AppImage's menu entry.
NAME := __NAME__
DESCRIPTION := Greet everyone listed in a Lua config

# vX.Y.Z[-N-gHASH][-dirty] from git, else the VERSION file that `make dist`
# puts in tarballs, else nothing (and the code falls back to "unknown")
VERSION := $(shell git describe --tags --match 'v*' --always --dirty 2>/dev/null)
ifeq ($(VERSION),)
VERSION := $(shell cat VERSION 2>/dev/null)
endif
DATE := $(shell git log -1 --format=%cs 2>/dev/null || date +%F)

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
# fish only looks for a user's completions in its own config dir
ifeq ($(PREFIX),$(HOME)/.local)
FISHCOMPDIR ?= $(HOME)/.config/fish/completions
else
FISHCOMPDIR ?= $(PREFIX)/share/fish/vendor_completions.d
endif

BUILD ?= build
BIN ?= $(NAME)
THIRDPARTY := src/thirdparty

ifeq ($(wildcard $(THIRDPARTY)/conf/CONF_FLAGS),)
$(error submodules missing, run: git submodule update --init)
endif
# Sets LUA (lua5.1 by default, `make LUA=luajit` also works), LUA_CFLAGS and LUA_LIBS
include $(THIRDPARTY)/conf/CONF_FLAGS

CFLAGS ?= -O2
CPPFLAGS += -D_DEFAULT_SOURCE -Isrc $(addprefix -I$(THIRDPARTY)/,flag cum conf) $(LUA_CFLAGS)
LDLIBS += $(LUA_LIBS) -pthread
ALL_CFLAGS = -std=c99 -Wall -Wextra $(CFLAGS)
DEFINES = -DNAME='"$(NAME)"' $(if $(VERSION),-DVERSION='"$(VERSION)"')

# Runtime checks for `make debug` and `make test`. address finds memory errors
# and leaks, undefined finds undefined behavior, and thread finds data races
# and deadlocks. thread can't be combined with address, so CI runs the tests
# once with each: `make test SANITIZE=thread`.
SANITIZE ?= address,undefined
SAN_FLAGS = -fsanitize=$(SANITIZE) -fno-sanitize-recover=all -fno-omit-frame-pointer
DEBUG_FLAGS = -O0 -ggdb $(SAN_FLAGS)

SRC := $(shell find src -name '*.c' -not -path '$(THIRDPARTY)/*')
OBJ := $(SRC:%.c=$(BUILD)/%.o)

# Rebuild everything when the flags or the version change (e.g. after `make debug`)
FLAGS := $(CC) $(ALL_CFLAGS) $(CPPFLAGS) $(DEFINES) $(LDFLAGS) $(LDLIBS)
ifneq ($(FLAGS),$(file < $(BUILD)/.flags))
$(shell mkdir -p $(BUILD))
$(file > $(BUILD)/.flags,$(FLAGS))
endif

.PHONY: all debug test format check-format docs man install uninstall appimage static dist completions changelog version hooks clean distclean

all: $(BIN)

$(BIN): $(OBJ) $(BUILD)/.flags
	$(CC) $(LDFLAGS) $(OBJ) $(LDLIBS) -o $@

$(BUILD)/%.o: %.c $(BUILD)/.flags
	@mkdir -p $(@D)
	$(CC) $(ALL_CFLAGS) $(CPPFLAGS) $(DEFINES) -MMD -MP -c $< -o $@

-include $(OBJ:.o=.d)

debug:
	$(MAKE) CFLAGS='$(DEBUG_FLAGS)' LDFLAGS='$(SAN_FLAGS)'

# The program and every test/*.c are built with the sanitizers, in their own
# build dir so the normal build is left alone. scripts/test.sh runs the tests.
comma := ,
TEST_BUILD := $(BUILD)/test/$(subst $(comma),-,$(SANITIZE))
test: export TEST_CC = $(CC)
test: export TEST_CFLAGS = -std=c99 -Wall -Wextra -O1 -ggdb $(SAN_FLAGS) $(CPPFLAGS)
test: export TEST_LDLIBS = $(SAN_FLAGS) $(LDLIBS)
test: export TEST_BIN = $(TEST_BUILD)/$(NAME)
test: export TEST_OUT = $(TEST_BUILD)/tests
test:
	@$(MAKE) --no-print-directory BUILD=$(TEST_BUILD) BIN=$(TEST_BUILD)/$(NAME) \
		CFLAGS='-O1 -ggdb $(SAN_FLAGS)' LDFLAGS='$(SAN_FLAGS)' $(TEST_BUILD)/$(NAME)
	@scripts/test.sh

# clang-format with .clang-format. CI checks with clang-format $(CLANG_FORMAT_VERSION)
# (pip install clang-format==$(CLANG_FORMAT_VERSION)): other versions may format differently.
CLANG_FORMAT ?= clang-format
CLANG_FORMAT_VERSION := 22.1.8
FORMAT_SRC = $(shell find src test -name '*.[ch]' -not -path '$(THIRDPARTY)/*')

format:
	$(CLANG_FORMAT) -i $(FORMAT_SRC)

check-format:
	$(CLANG_FORMAT) --dry-run -Werror $(FORMAT_SRC)

docs:
	@find docs -name '*.typ' | while read -r f; do echo "typst compile $$f"; typst compile "$$f" || exit 1; done

# The man page with its version and date, $(NAME).1 (attached to releases)
man: $(BUILD)/$(NAME).1
	cp $< $(NAME).1

$(BUILD)/$(NAME).1: docs/$(NAME).1 $(BUILD)/.flags
	sed 's/@VERSION@/$(or $(VERSION),unknown)/; s/@DATE@/$(DATE)/' $< >$@

install: $(NAME) $(BUILD)/$(NAME).1
	install -Dm755 $(NAME) $(DESTDIR)$(BINDIR)/$(NAME)
	install -Dm644 $(BUILD)/$(NAME).1 $(DESTDIR)$(MANDIR)/$(NAME).1
	install -Dm644 completions/$(NAME).bash $(DESTDIR)$(BASHCOMPDIR)/$(NAME)
	install -Dm644 completions/_$(NAME) $(DESTDIR)$(ZSHCOMPDIR)/_$(NAME)
	install -Dm644 completions/$(NAME).fish $(DESTDIR)$(FISHCOMPDIR)/$(NAME).fish

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(NAME) $(DESTDIR)$(MANDIR)/$(NAME).1 $(DESTDIR)$(BASHCOMPDIR)/$(NAME) \
		$(DESTDIR)$(ZSHCOMPDIR)/_$(NAME) $(DESTDIR)$(FISHCOMPDIR)/$(NAME).fish

# Bundles every shared library the binary needs (except glibc and friends, see
# linuxdeploy's excludelist) into $(NAME)-$(ARCH).AppImage, for the machine's
# arch (x86_64 or aarch64)
ARCH := $(shell uname -m)
TOOLS := $(BUILD)/tools
APPDIR := $(BUILD)/AppDir
APPIMAGE := $(NAME)-$(ARCH).AppImage
# The tools are AppImages too: run them without FUSE (CI has none)
export APPIMAGE_EXTRACT_AND_RUN = 1

appimage: $(APPIMAGE)

$(APPIMAGE): $(NAME) assets/icon.svg $(TOOLS)/linuxdeploy $(TOOLS)/appimagetool
	rm -rf $(APPDIR)
	mkdir -p $(APPDIR)
	printf '[Desktop Entry]\nType=Application\nName=%s\nComment=%s\nExec=%s\nIcon=%s\nTerminal=true\nCategories=Utility;\n' \
		'$(NAME)' '$(subst ','\'',$(DESCRIPTION))' '$(NAME)' '$(NAME)' >$(BUILD)/$(NAME).desktop
	cp assets/icon.svg $(BUILD)/$(NAME).svg
	$(TOOLS)/linuxdeploy --appdir $(APPDIR) --executable $(NAME) \
		--desktop-file $(BUILD)/$(NAME).desktop --icon-file $(BUILD)/$(NAME).svg
	ARCH=$(ARCH) $(TOOLS)/appimagetool --no-appstream $(APPDIR) $@

$(TOOLS)/linuxdeploy:
	@mkdir -p $(@D)
	curl -fsSL -o $@ https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-$(ARCH).AppImage
	chmod +x $@

$(TOOLS)/appimagetool:
	@mkdir -p $(@D)
	curl -fsSL -o $@ https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$(ARCH).AppImage
	chmod +x $@

# Fully static binary, $(NAME)-$(ARCH)-static, that runs on any Linux of its
# arch. Distro Lua libraries are built for glibc, so Lua is built from source
# with musl (needs musl-gcc: the musl package on Arch, musl-tools on Debian).
MUSL_CC ?= musl-gcc
STATIC := $(NAME)-$(ARCH)-static
LUA_VERSION := 5.1.5
LUA_SHA256 := 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
LUA_SRC := $(TOOLS)/lua-$(LUA_VERSION)/src

static: $(STATIC)

$(STATIC): $(LUA_SRC)/liblua.a FORCE
	@$(MAKE) --no-print-directory BUILD=$(BUILD)/static BIN=$(BUILD)/static/$(NAME) CC=$(MUSL_CC) \
		LUA_CFLAGS=-I$(LUA_SRC) LUA_LIBS='$(LUA_SRC)/liblua.a -lm' LDFLAGS='-static -s' $(BUILD)/static/$(NAME)
	cp $(BUILD)/static/$(NAME) $@

$(LUA_SRC)/liblua.a:
	@mkdir -p $(TOOLS)
	curl -fsSL -o $(TOOLS)/lua-$(LUA_VERSION).tar.gz https://www.lua.org/ftp/lua-$(LUA_VERSION).tar.gz
	echo '$(LUA_SHA256)  $(TOOLS)/lua-$(LUA_VERSION).tar.gz' | sha256sum -c --quiet
	tar -xzf $(TOOLS)/lua-$(LUA_VERSION).tar.gz -C $(TOOLS)
	$(MAKE) -C $(LUA_SRC) a CC=$(MUSL_CC) MYCFLAGS=-DLUA_USE_POSIX

FORCE:

# Source tarball with the submodules and a VERSION file (GitHub's own
# tarballs have neither)
dist:
	@test -n "$(VERSION)" || { echo "dist: no version, not a git checkout?"; exit 1; }
	rm -rf $(BUILD)/dist && mkdir -p $(BUILD)/dist/$(NAME)-$(VERSION)
	git ls-files --recurse-submodules | tar -cf - -T - | tar -xf - -C $(BUILD)/dist/$(NAME)-$(VERSION)
	echo $(VERSION) >$(BUILD)/dist/$(NAME)-$(VERSION)/VERSION
	tar -czf $(NAME)-$(VERSION).tar.gz -C $(BUILD)/dist $(NAME)-$(VERSION)

# The completions on their own, for the static binary and the AppImage
completions:
	tar -czf $(NAME)-completions.tar.gz --transform 's|^completions|$(NAME)-completions|' completions

# Grouped commit messages since the first release, like each release has
changelog:
	@mkdir -p $(BUILD)
	scripts/changelog.sh >$(BUILD)/CHANGELOG.md
	mv $(BUILD)/CHANGELOG.md CHANGELOG.md

version:
	@echo $(or $(VERSION),unknown)

# Run the tests before every `git push`
hooks:
	git config core.hooksPath scripts/hooks

# What the build makes. The downloaded tools and Lua are kept.
clean:
	rm -rf $(NAME) $(NAME).1 CHANGELOG.md $(BUILD)/.flags $(BUILD)/src $(BUILD)/test $(BUILD)/AppDir $(BUILD)/dist $(BUILD)/static $(BUILD)/$(NAME).*

# Back to a fresh clone: also the tools, Lua, AppImages, static binaries,
# tarballs and PDFs
distclean: clean
	rm -rf $(BUILD) $(NAME)-*.AppImage $(NAME)-*-static $(NAME)-*.tar.gz
	find docs -name '*.pdf' -delete
