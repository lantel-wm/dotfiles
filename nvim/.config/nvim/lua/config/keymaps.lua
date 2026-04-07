local map = vim.keymap.set
local cheatsheet = require("config.cheatsheet")
local diagnostics = require("config.diagnostics")

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics list" })
map("n", "<leader>h", cheatsheet.toggle, { desc = "Open cheatsheet" })
map("n", "<leader>td", diagnostics.toggle_virtual_text, { desc = "Toggle diagnostic virtual text" })
map({ "n", "v" }, "<leader>cf", function()
  require("conform").format({
    async = false,
    lsp_format = "fallback",
  })
end, { desc = "Format buffer" })

for _, mode in ipairs({ "n", "x" }) do
  map(mode, "<C-h>", "<Nop>")
  map(mode, "<C-k>", "10k", { desc = "Up 10 lines" })
  map(mode, "<C-j>", "10j", { desc = "Down 10 lines" })
end

vim.api.nvim_create_user_command("Cheatsheet", cheatsheet.toggle, {
  desc = "Open the local Neovim cheatsheet",
})

vim.api.nvim_create_user_command("Format", function()
  require("conform").format({
    async = false,
    lsp_format = "fallback",
  })
end, {
  desc = "Format current buffer",
})
