// Every .typ under docs/ is compiled by `make docs` and attached to each
// release (CI builds them with the latest Typst).
#set document(title: "template manual")
#set page(paper: "a4", numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)
#set heading(numbering: "1.")

#align(center, text(20pt, weight: "bold")[template])
#align(center)[Greet everyone listed in a Lua config]

= Usage

```sh
template [-h] [-v] [-c FILE]
```

/ `-h`, `--help`: show the help.
/ `-v`, `--version`: show the version.
/ `-c`, `--config FILE`: use `FILE` as the config.

= Configuration

The config is Lua. The first of these that exists is used:

+ `$XDG_CONFIG_HOME/template/config.lua` (`~/.config/template/config.lua`)
+ `./config.lua`

```lua
Config = {
    greeting = "Hello",
    times = 1,
    names = { "world" },
}
```
