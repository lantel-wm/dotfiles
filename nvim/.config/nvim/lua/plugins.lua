local function project_root(bufnr)
  return vim.fs.root(bufnr, {
    ".git",
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "compile_commands.json",
    "compile_flags.txt",
  })
end

local function find_executable(bufnr, names)
  local root = project_root(bufnr)

  if root then
    for _, dir in ipairs({ "node_modules/.bin", ".venv/bin", "venv/bin" }) do
      for _, name in ipairs(names) do
        local candidate = root .. "/" .. dir .. "/" .. name
        if vim.uv.fs_stat(candidate) then
          return candidate
        end
      end
    end
  end

  for _, name in ipairs(names) do
    local executable = vim.fn.exepath(name)
    if executable ~= "" then
      return executable
    end
  end
end

local treesitter_languages = {
  "bash",
  "c",
  "cpp",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "rust",
  "toml",
  "typescript",
  "tsx",
  "vim",
  "vimdoc",
  "yaml",
}

local treesitter_install_dir = vim.fn.stdpath("data") .. "/treesitter-site"
local treesitter_filetypes = {
  "bash",
  "c",
  "cpp",
  "javascript",
  "javascriptreact",
  "json",
  "lua",
  "markdown",
  "python",
  "query",
  "rust",
  "sh",
  "toml",
  "typescript",
  "typescriptreact",
  "vim",
  "vimdoc",
  "yaml",
  "zsh",
}

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "macchiato",
      integrations = {
        telescope = { enabled = true },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-lua/plenary.nvim",
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local builtin = require("telescope.builtin")

      telescope.setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_config = {
            prompt_position = "top",
          },
          mappings = {
            i = {
              ["<Esc>"] = actions.close,
            },
          },
        },
        pickers = {
          lsp_references = {
            show_line = false,
          },
        },
      })

      pcall(telescope.load_extension, "fzf")

      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")

      treesitter.setup({
        install_dir = treesitter_install_dir,
      })

      vim.treesitter.language.register("bash", { "sh", "zsh" })
      vim.treesitter.language.register("javascript", { "javascriptreact" })
      vim.treesitter.language.register("tsx", { "typescriptreact" })

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user-treesitter-start", { clear = true }),
        pattern = treesitter_filetypes,
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })

      local installed = {}
      for _, lang in ipairs(treesitter.get_installed("parsers")) do
        installed[lang] = true
      end

      local missing = vim.tbl_filter(function(lang)
        return not installed[lang]
      end, treesitter_languages)

      if #missing > 0 then
        vim.schedule(function()
          treesitter.install(missing, { summary = false })
        end)
      end
    end,
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = { preset = "default" },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        documentation = { auto_show = false },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      require("config.lsp").setup()
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    version = "1.*",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = function()
      local function toggle_diffthis()
        local current_tab = vim.api.nvim_get_current_tabpage()
        local current_win = vim.api.nvim_get_current_win()

        if vim.wo[current_win].diff then
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current_tab)) do
            if vim.api.nvim_win_is_valid(win) then
              local buf = vim.api.nvim_win_get_buf(win)
              local name = vim.api.nvim_buf_get_name(buf)

              if vim.wo[win].diff then
                vim.wo[win].diff = false
              end

              if win ~= current_win and name:match("^gitsigns://") then
                pcall(vim.api.nvim_win_close, win, true)
              end
            end
          end

          return
        end

        require("gitsigns").diffthis()
      end

      return {
        signs = {
          add = { text = "|" },
          change = { text = "|" },
          delete = { text = "_" },
          topdelete = { text = "-" },
          changedelete = { text = "~" },
        },
        attach_to_untracked = true,
        current_line_blame = false,
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        watch_gitdir = {
          follow_files = true,
        },
        on_attach = function(bufnr)
          local gitsigns = require("gitsigns")
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "]c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gitsigns.nav_hunk("next")
            end
          end, "Next git hunk")

          map("n", "[c", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gitsigns.nav_hunk("prev")
            end
          end, "Previous git hunk")

          map("n", "<leader>gp", gitsigns.preview_hunk_inline, "Preview hunk")
          map("n", "<leader>gb", gitsigns.blame_line, "Blame line")
          map("n", "<leader>gB", gitsigns.toggle_current_line_blame, "Toggle line blame")
          map("n", "<leader>gs", gitsigns.stage_hunk, "Stage hunk")
          map("n", "<leader>gR", gitsigns.reset_hunk, "Reset hunk")
          map("n", "<leader>gd", toggle_diffthis, "Toggle diff view")
        end,
      }
    end,
  },
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")

      lint.linters.eslint_local = function()
        local cmd = find_executable(0, { "eslint_d", "eslint" })
        local base = lint.linters[cmd and cmd:match("eslint_d$") and "eslint_d" or "eslint"]
        local linter = type(base) == "function" and base() or vim.deepcopy(base)

        linter.cmd = cmd or "eslint"
        return linter
      end

      local linters_by_ft = {
        bash = { "shellcheck" },
        javascript = { "eslint_local" },
        javascriptreact = { "eslint_local" },
        python = { "ruff" },
        sh = { "shellcheck" },
        typescript = { "eslint_local" },
        typescriptreact = { "eslint_local" },
        zsh = { "zsh" },
      }

      lint.linters_by_ft = linters_by_ft

      local available = {
        eslint_local = function()
          return find_executable(0, { "eslint_d", "eslint" }) ~= nil
        end,
        ruff = function()
          return find_executable(0, { "ruff" }) ~= nil
        end,
        shellcheck = function()
          return find_executable(0, { "shellcheck" }) ~= nil
        end,
        zsh = function()
          return find_executable(0, { "zsh" }) ~= nil
        end,
      }

      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("user-lint", { clear = true }),
        callback = function(args)
          local names = linters_by_ft[vim.bo[args.buf].filetype] or {}
          local enabled = {}

          for _, name in ipairs(names) do
            if not available[name] or available[name]() then
              table.insert(enabled, name)
            end
          end

          if #enabled > 0 then
            lint.try_lint(enabled)
          end
        end,
      })
    end,
  },
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    opts = {
      enable_autocmd = false,
    },
  },
  {
    "numToStr/Comment.nvim",
    dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
    opts = function()
      return {
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      }
    end,
  },
}
