local M = {}

local state = {
  buf = nil,
  win = nil,
}

local function contents()
  return {
    "Neovim Cheatsheet",
    "",
    "Leader key: <Space>",
    "Open or close this window: <leader>h or :Cheatsheet",
    "Close this window: q or <Esc>",
    "",
    "General",
    "  <leader>h   Toggle this cheatsheet",
    "  :Cheatsheet Toggle this cheatsheet",
    "  <Esc>       Clear search highlight",
    "  <C-k>       Move up 10 lines",
    "  <C-j>       Move down 10 lines",
    "",
    "Search",
    "  <leader>ff  Find files",
    "  <leader>fg  Live grep",
    "  <leader>fb  Buffer list",
    "  <leader>/   Search current buffer",
    "  <leader>fr  Resume last picker",
    "  <leader>fd  Buffer diagnostics picker",
    "  <leader>fk  Keymaps picker",
    "  <leader>fh  Help tags",
    "",
    "Git",
    "  [c          Previous git hunk",
    "  ]c          Next git hunk",
    "  <leader>gp  Preview current hunk",
    "  <leader>gb  Blame current line",
    "  <leader>gB  Toggle current line blame",
    "  <leader>gs  Stage current hunk",
    "  <leader>gR  Reset current hunk",
    "  <leader>gd  Toggle diff view",
    "",
    "LSP",
    "  gd          Go to definition",
    "  gD          Go to declaration",
    "  gr          Find references",
    "  gi          Find implementations",
    "  gy          Find type definitions",
    "  K           Hover docs",
    "  <leader>rn  Rename symbol",
    "  <leader>ca  Code action",
    "",
    "Diagnostics",
    "  [d          Previous diagnostic",
    "  ]d          Next diagnostic",
    "  <leader>e   Line diagnostics",
    "  <leader>q   Diagnostics list",
    "  <leader>td  Toggle diagnostic virtual text",
    "",
    "Comments",
    "  gcc         Toggle current line comment",
    "  gc{motion}  Toggle comment for a motion",
    "  gbc         Toggle current block comment",
    "  gb{motion}  Toggle block comment for a motion",
    "  gc in visual mode comments selection",
    "  gco/gcO     Add comment below/above",
    "  gcA         Add comment at end of line",
    "",
    "Completion",
    "  <C-Space>   Open completion menu",
    "  <C-n>/<C-p> Select next/previous item",
    "  <Up>/<Down> Select next/previous item",
    "  <C-y>       Accept selected item",
    "  <C-e>       Cancel completion",
    "  <C-b>/<C-f> Scroll completion docs",
    "  <Tab>       Jump to next snippet field",
    "  <S-Tab>     Jump to previous snippet field",
    "  <C-k>       Toggle signature help (insert mode)",
    "",
    "Clipboard",
    "  y / p       Use system clipboard by default",
    '  "+y         Explicitly yank to system clipboard',
    '  "+p         Explicitly paste from system clipboard',
    "",
    "Formatting",
    "  <leader>cf  Format current buffer or selection",
    "  :Format     Format current buffer",
    "",
    "Language Tools",
    "  Python      basedpyright + ruff",
    "  Rust        rust-analyzer (clippy)",
    "  Shell       bashls + shellcheck",
    "  C/C++       clangd",
    "  TypeScript  ts_ls + eslint",
    "",
    "Notes",
    "  Python LSP only starts inside real Python projects",
    "  Treesitter parsers are installed in a dedicated runtime path",
    "  Run :TSInstallConfigured on a fresh machine to install configured parsers",
  }
end

local function dimensions(lines)
  local max_line = 0

  for _, line in ipairs(lines) do
    max_line = math.max(max_line, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(math.max(max_line + 4, 64), math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 2, math.floor((vim.o.lines - vim.o.cmdheight) * 0.85))

  return width, height
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  state.win = nil
end

function M.show()
  local lines = contents()

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].filetype = "markdown"
  end

  local width, height = dimensions(lines)

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.bo[state.buf].readonly = true

  local row = math.floor(((vim.o.lines - vim.o.cmdheight) - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    row = math.max(row, 1),
    col = math.max(col, 0),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Cheatsheet ",
    title_pos = "center",
  })

  vim.wo[state.win].wrap = true
  vim.wo[state.win].linebreak = true
  vim.wo[state.win].conceallevel = 0
  vim.wo[state.win].cursorline = false
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"

  for _, key in ipairs({ "q", "<Esc>", "<leader>h" }) do
    vim.keymap.set("n", key, M.close, { buffer = state.buf, silent = true })
  end
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  else
    M.show()
  end
end

return M
