-- An example config. Copy it to ~/.config/__NAME__/config.lua to use it, or
-- pass it with --config: one in the current directory isn't read on its own.
-- It's plain Lua (5.4), so you can compute values, use os.getenv(), etc.
Config = {
    greeting = "Hello",
    times = 1,
    names = { "world", os.getenv("USER") or "you" },
}
