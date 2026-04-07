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
local python_base_excludes = {
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
}
local workspace_root_markers = {
  ".git",
  "package.json",
  "pyproject.toml",
  "Cargo.toml",
  "compile_commands.json",
  "compile_flags.txt",
}
local ts_root_markers = {
  { "tsconfig.json", "jsconfig.json", "package.json" },
  { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
}

local function map(bufnr, mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
end

local function current_file_dir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
end

local function python_project_root(bufnr)
  return vim.fs.root(bufnr, python_root_markers)
end

local python_gitignore_exclude_cache = {}

local function merge_unique_patterns(...)
  local merged = {}
  local seen = {}

  for i = 1, select("#", ...) do
    for _, pattern in ipairs(select(i, ...)) do
      if pattern and pattern ~= "" and not seen[pattern] then
        seen[pattern] = true
        table.insert(merged, pattern)
      end
    end
  end

  return merged
end

local function gitignore_to_pyright_pattern(line)
  local pattern = vim.trim(line)

  if pattern == "" or vim.startswith(pattern, "#") or vim.startswith(pattern, "!") then
    return nil
  end

  if vim.startswith(pattern, "\\#") or vim.startswith(pattern, "\\!") then
    pattern = pattern:sub(2)
  end

  local anchored = vim.startswith(pattern, "/")
  pattern = pattern:gsub("^/", ""):gsub("/$", ""):gsub("^%./", "")

  if pattern == "" then
    return nil
  end

  if anchored or pattern:find("/", 1, true) then
    return pattern
  end

  return "**/" .. pattern
end

local function python_gitignore_excludes(root)
  if not root or root == "" then
    return {}
  end

  if python_gitignore_exclude_cache[root] then
    return python_gitignore_exclude_cache[root]
  end

  local gitignore = root .. "/.gitignore"
  local ok, lines = pcall(vim.fn.readfile, gitignore)

  if not ok then
    python_gitignore_exclude_cache[root] = {}
    return python_gitignore_exclude_cache[root]
  end

  local patterns = {}

  for _, line in ipairs(lines) do
    table.insert(patterns, gitignore_to_pyright_pattern(line))
  end

  python_gitignore_exclude_cache[root] = merge_unique_patterns(patterns)
  return python_gitignore_exclude_cache[root]
end

local function python_analysis_excludes(root)
  return merge_unique_patterns(python_base_excludes, python_gitignore_excludes(root))
end

local function picker_cwd(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.root_dir and client.root_dir ~= "" then
      return client.root_dir
    end
  end

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

local function sort_and_dedupe_items(items)
  local deduped = {}
  local seen = {}

  for _, item in ipairs(items) do
    local key = table.concat({
      item.filename or "",
      tostring(item.lnum or 0),
      tostring(item.col or 0),
    }, ":")

    if not seen[key] then
      seen[key] = true
      table.insert(deduped, item)
    end
  end

  table.sort(deduped, function(a, b)
    if a.filename ~= b.filename then
      return (a.filename or "") < (b.filename or "")
    end

    if a.lnum ~= b.lnum then
      return (a.lnum or 0) < (b.lnum or 0)
    end

    return (a.col or 0) < (b.col or 0)
  end)

  return deduped
end

local function telescope_location_picker(title, items, bufnr)
  local pickers = require("telescope.pickers")
  local entry_display = require("telescope.pickers.entry_display")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")
  local cwd = picker_cwd(bufnr)
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { remaining = true },
    },
  })

  local entry_maker = function(item)
    local relative = vim.fn.fnamemodify(item.filename, ":.")
    local display_name = vim.fn.fnamemodify(relative, ":t")

    return make_entry.set_default_entry_mt({
      value = item,
      ordinal = table.concat({
        item.filename or "",
        display_name,
        relative,
        tostring(item.lnum or 0),
        item.text or "",
      }, " "),
      display = function(entry)
        return displayer({
          {
            string.format("%s:%s", entry.display_name, tostring(entry.lnum)),
            "TelescopeResultsIdentifier",
          },
        })
      end,
      display_name = display_name,
      filename = item.filename,
      lnum = item.lnum,
      col = item.col,
      text = item.text,
      start = item.lnum,
      path = item.filename,
    }, {
      cwd = cwd,
    })
  end

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = items,
        entry_maker = entry_maker,
      }),
      layout_strategy = "horizontal",
      layout_config = {
        preview_width = 0.6,
      },
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
          postprocess = sort_and_dedupe_items,
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
    root_dir = function(bufnr, on_dir)
      local root = python_project_root(bufnr)

      if root then
        on_dir(root)
      end
    end,
    before_init = function(init_params, config)
      local root = init_params.rootUri and vim.uri_to_fname(init_params.rootUri) or init_params.rootPath

      config.settings = config.settings or {}
      config.settings.basedpyright = config.settings.basedpyright or {}
      config.settings.basedpyright.analysis =
        vim.tbl_deep_extend("force", {}, config.settings.basedpyright.analysis or {})
      config.settings.basedpyright.analysis.exclude = python_analysis_excludes(root)
    end,
    root_markers = python_root_markers,
    single_file_support = false,
    settings = {
      basedpyright = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = "openFilesOnly",
          typeCheckingMode = "basic",
          useLibraryCodeForTypes = true,
          exclude = python_base_excludes,
        },
      },
    },
  })

  vim.lsp.config("ts_ls", {
    root_dir = function(bufnr, on_dir)
      local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" })

      if deno_root then
        return
      end

      on_dir(vim.fs.root(bufnr, ts_root_markers) or current_file_dir(bufnr))
    end,
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
