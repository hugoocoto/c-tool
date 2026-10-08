-- Default config. Copy it to ~/.config/__NAME__/config.lua to change it:
-- that one is used first, and this one only when it doesn't exist.
-- It's plain Lua (5.1), so you can compute values, use os.getenv(), etc.
Config = {
    greeting = "Hello",
    times = 1,
    names = { "world", os.getenv("USER") or "you" },
}
