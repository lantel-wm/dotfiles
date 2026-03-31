require("git"):setup()

require("starship"):setup({
    hide_flags = false,
    flags_after_prompt = true,
    config_file = "~/.config/starship_full.toml",
})
