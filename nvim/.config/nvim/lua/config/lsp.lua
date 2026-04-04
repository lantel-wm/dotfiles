local M = {}
local python_root_markers = {
  "pyrightconfig.json",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "uv.lock",
  "poetry.lock",
}
local workspace_root_markers = {
  ".git",
  "package.json",
  "pyproject.toml",
  "Cargo.toml",
  "compile_commands.json",
  "compile_flags.txt",
}

local function map(bufnr, mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
end

local function picker_cwd(bufnr)
  return vim.fs.root(bufnr, workspace_root_markers) or vim.fn.getcwd()
end

local function jump_to_qf_item(item)
  if not item then
    return
  end

  local bufnr = item.bufnr and item.bufnr > 0 and item.bufnr or vim.fn.bufadd(item.filename)

  vim.cmd("normal! m'")
  vim.bo[bufnr].buflisted = true
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
  vim.cmd("normal! zv")
end

local function telescope_location_picker(title, items, bufnr)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")
  local cwd = picker_cwd(bufnr)

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = items,
        entry_maker = make_entry.gen_from_quickfix({
          cwd = cwd,
          path_display = {
            shorten = 1,
            truncate = 3,
          },
        }),
      }),
      previewer = conf.qflist_previewer({}),
      sorter = conf.generic_sorter({}),
      push_cursor_on_edit = true,
      push_tagstack_on_edit = true,
    })
    :find()
end

local function telescope_lsp_locations(method, title, opts)
  opts = opts or {}

  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    if vim.tbl_isempty(vim.lsp.get_clients({ bufnr = bufnr, method = method })) then
      vim.notify(vim.lsp._unsupported_method(method), vim.log.levels.WARN)
      return
    end

    local params = opts.params or function(client)
      return vim.lsp.util.make_position_params(win, client.offset_encoding)
    end

    vim.lsp.buf_request_all(bufnr, method, params, function(results)
      local items = {}

      for client_id, response in pairs(results) do
        if response.err then
          vim.notify(
            string.format("%s: %s", method, response.err.message or "request failed"),
            vim.log.levels.WARN
          )
        elseif response.result then
          local client = vim.lsp.get_client_by_id(client_id)
          local locations = vim.islist(response.result) and response.result or { response.result }

          if client and client.offset_encoding and not vim.tbl_isempty(locations) then
            vim.list_extend(items, vim.lsp.util.locations_to_items(locations, client.offset_encoding))
          end
        end
      end

      if opts.postprocess then
        items = opts.postprocess(items)
      end

      if vim.tbl_isempty(items) then
        vim.notify("No locations found", vim.log.levels.INFO)
      elseif #items == 1 then
        jump_to_qf_item(items[1])
      else
        telescope_location_picker(title, items, bufnr)
      end
    end)
  end
end

function M.setup()
  local capabilities = require("blink.cmp").get_lsp_capabilities()

  vim.diagnostic.config({
    severity_sort = true,
    underline = true,
    update_in_insert = false,
    virtual_text = {
      spacing = 2,
      source = "if_many",
    },
    float = {
      border = "rounded",
      source = "if_many",
    },
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
    callback = function(args)
      local bufnr = args.buf

      map(bufnr, "n", "gd", telescope_lsp_locations("textDocument/definition", "LSP Definitions"), "Go to definition")
      map(bufnr, "n", "gD", function()
        vim.lsp.buf.declaration({ reuse_win = true })
      end, "Go to declaration")
      map(
        bufnr,
        "n",
        "gr",
        telescope_lsp_locations("textDocument/references", "LSP References", {
          params = function(client)
            local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
            params.context = { includeDeclaration = true }
            return params
          end,
        }),
        "References"
      )
      map(
        bufnr,
        "n",
        "gi",
        telescope_lsp_locations("textDocument/implementation", "LSP Implementations"),
        "Implementations"
      )
      map(
        bufnr,
        "n",
        "gy",
        telescope_lsp_locations("textDocument/typeDefinition", "LSP Type Definitions"),
        "Type definitions"
      )
      map(bufnr, "n", "K", vim.lsp.buf.hover, "Hover")
      map(bufnr, "n", "<leader>rn", vim.lsp.buf.rename, "Rename")
      map(bufnr, { "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    end,
  })

  vim.lsp.config("*", {
    capabilities = capabilities,
  })

  vim.lsp.config("basedpyright", {
    root_markers = python_root_markers,
    single_file_support = false,
    settings = {
      basedpyright = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = "openFilesOnly",
          typeCheckingMode = "basic",
          useLibraryCodeForTypes = true,
          exclude = {
            "**/.git",
            "**/.hg",
            "**/.svn",
            "**/__pycache__",
            "**/.mypy_cache",
            "**/.pytest_cache",
            "**/.ruff_cache",
            "**/.tox",
            "**/.venv",
            "**/venv",
            "**/node_modules",
            "**/dist",
            "**/build",
          },
        },
      },
    },
  })

  vim.lsp.config("rust_analyzer", {
    settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
        check = { command = "clippy" },
      },
    },
  })

  vim.lsp.config("clangd", {
    cmd = { "clangd", "--background-index", "--clang-tidy" },
  })

  vim.lsp.enable({
    "basedpyright",
    "rust_analyzer",
    "clangd",
    "bashls",
    "ts_ls",
  })
end

return M
