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
    lazy = false,
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
    cmd = { "Telescope" },
    keys = {
      {
        "<leader>ff",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Live grep",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Buffer list",
      },
      {
        "<leader>/",
        function()
          local themes = require("telescope.themes")
          require("telescope.builtin").current_buffer_fuzzy_find(themes.get_dropdown({
            previewer = false,
          }))
        end,
        desc = "Search current buffer",
      },
      {
        "<leader>fr",
        function()
          require("telescope.builtin").resume()
        end,
        desc = "Resume search",
      },
      {
        "<leader>fd",
        function()
          require("telescope.builtin").diagnostics({ bufnr = 0 })
        end,
        desc = "Buffer diagnostics picker",
      },
      {
        "<leader>fk",
        function()
          require("telescope.builtin").keymaps()
        end,
        desc = "Keymaps picker",
      },
      {
        "<leader>fh",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "Help tags",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          cache_picker = {
            num_pickers = 10,
          },
          file_ignore_patterns = {
            "^%.git/",
            "^node_modules/",
            "^%.venv/",
            "^venv/",
            "^__pycache__/",
            "^%.ruff_cache/",
            "^%.pytest_cache/",
            "^%.mypy_cache/",
            "^dist/",
            "^build/",
            "^tmp/",
          },
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
          buffers = {
            ignore_current_buffer = true,
            sort_lastused = true,
          },
          lsp_references = {
            show_line = false,
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
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

      vim.api.nvim_create_user_command("TSInstallConfigured", function()
        treesitter.install(treesitter_languages, { summary = true })
      end, {
        desc = "Install configured Tree-sitter parsers",
      })
    end,
  },
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = { preset = "super-tab" },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 500,
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
      signature = {
        enabled = true,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = { "saghen/blink.cmp" },
    config = function()
      require("config.lsp").setup()
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    version = "1.*",
    event = { "BufReadPre", "BufNewFile" },
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
    event = { "BufReadPre", "BufNewFile" },
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
    "numToStr/Comment.nvim",
    keys = {
      { "gc", mode = { "n", "x", "o" } },
      { "gb", mode = { "n", "x", "o" } },
      { "gco", mode = "n" },
      { "gcO", mode = "n" },
      { "gcA", mode = "n" },
      { "gbc", mode = "n" },
    },
    dependencies = {
      {
        "JoosepAlviste/nvim-ts-context-commentstring",
        lazy = true,
        opts = {
          enable_autocmd = false,
        },
      },
    },
    opts = function()
      return {
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    opts = function()
      local prettier_local = function(bufnr)
        local cmd = find_executable(bufnr, { "prettierd", "prettier" })
        if not cmd then
          return
        end

        return {
          inherit = cmd:match("prettierd$") and "prettierd" or "prettier",
          command = cmd,
        }
      end

      return {
        default_format_opts = {
          lsp_format = "fallback",
        },
        notify_no_formatters = false,
        formatters = {
          prettier_local = prettier_local,
          shfmt = {
            append_args = { "-i", "2" },
          },
        },
        formatters_by_ft = {
          c = { "clang_format" },
          cpp = { "clang_format" },
          javascript = { "prettier_local" },
          javascriptreact = { "prettier_local" },
          json = { "prettier_local" },
          lua = { "stylua" },
          markdown = { "prettier_local" },
          python = { "ruff_format" },
          rust = { "rustfmt" },
          sh = { "shfmt" },
          typescript = { "prettier_local" },
          typescriptreact = { "prettier_local" },
          yaml = { "prettier_local" },
          zsh = { "shfmt" },
        },
      }
    end,
  },
}
