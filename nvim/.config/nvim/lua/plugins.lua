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

local treesitter_parser_dir = vim.fn.stdpath("data") .. "/treesitter"

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      integrations = {
        telescope = {
          enabled = true,
        },
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
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-fzf-native.nvim",
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
    branch = "master",
    build = ":TSUpdate",
    config = function()
      vim.opt.runtimepath:prepend(treesitter_parser_dir)

      require("nvim-treesitter.configs").setup({
        parser_install_dir = treesitter_parser_dir,
        ensure_installed = treesitter_languages,
        highlight = { enable = true },
        indent = { enable = false },
      })
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
