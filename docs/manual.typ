// Every .typ under docs/ is compiled by `make docs` and attached to each
// release (CI builds them with the latest Typst).
#set document(title: "__NAME__ manual")
#set page(paper: "a4", numbering: "1")
#set text(font: "New Computer Modern", size: 11pt)
#set heading(numbering: "1.")

#align(center, text(20pt, weight: "bold")[__NAME__])
#align(center)[Greet everyone listed in a Lua config]

= Usage

```sh
__NAME__ [-h] [-v] [-c FILE]
```

/ `-h`, `--help`: show the help.
/ `-v`, `--version`: show the version.
/ `-c`, `--config FILE`: use `FILE` as the config.

= Configuration

The config is Lua. The first of these that exists is used:

+ `$XDG_CONFIG_HOME/__NAME__/config.lua` (`~/.config/__NAME__/config.lua`)
+ `./config.lua`

```lua
Config = {
    greeting = "Hello",
    times = 1,
    names = { "world" },
}
```
