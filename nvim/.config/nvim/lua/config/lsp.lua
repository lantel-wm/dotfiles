local M = {}
local diagnostics = require("config.diagnostics")
local python_root_markers = {
  "ty.toml",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "uv.lock",
  "poetry.lock",
  "ruff.toml",
  ".ruff.toml",
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

local function valid_python_workspace_root(root)
  if not root or root == "" or not vim.uv.fs_stat(root) then
    return false
  end

  return vim.fs.root(root, python_root_markers) == root
end

local function remember_python_workspace_root(root)
  if not valid_python_workspace_root(root) then
    return
  end

  vim.w.python_workspace_root = root
  vim.t.python_workspace_root = root
end

local function inherited_python_workspace_root()
  if valid_python_workspace_root(vim.w.python_workspace_root) then
    return vim.w.python_workspace_root
  end

  if valid_python_workspace_root(vim.t.python_workspace_root) then
    return vim.t.python_workspace_root
  end

  local cwd_root = vim.fs.root(vim.fn.getcwd(), python_root_markers)
  if valid_python_workspace_root(cwd_root) then
    return cwd_root
  end
end

local function python_workspace_root(bufnr)
  return python_project_root(bufnr) or inherited_python_workspace_root()
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

local function dedupe_items(items)
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

  return deduped
end

local function telescope_location_picker(title, items, bufnr, opts)
  opts = opts or {}
  local pickers = require("telescope.pickers")
  local entry_display = require("telescope.pickers.entry_display")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")
  local sorters = require("telescope.sorters")
  local cwd = picker_cwd(bufnr)
  local basename_counts = {}
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { remaining = true },
    },
  })

  for _, item in ipairs(items) do
    local basename = vim.fs.basename(item.filename)
    basename_counts[basename] = (basename_counts[basename] or 0) + 1
  end

  local entry_maker = function(item)
    local relative = (cwd and vim.fs.relpath(cwd, item.filename)) or item.filename
    local basename = vim.fs.basename(relative)
    local display_name = basename

    if (basename_counts[basename] or 0) > 1 then
      local parent = vim.fn.fnamemodify(relative, ":h:t")

      if parent ~= "" and parent ~= "." then
        display_name = string.format("%s/%s", parent, basename)
      else
        display_name = relative
      end
    end

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
      layout_strategy = opts.layout_strategy or "horizontal",
      layout_config = opts.layout_strategy == "vertical"
          and (opts.layout_config or {})
        or vim.tbl_deep_extend("force", {
          preview_width = 0.6,
        }, opts.layout_config or {}),
      previewer = opts.previewer == false and false or conf.qflist_previewer({}),
      sorter = opts.sorter == "empty" and sorters.empty() or conf.generic_sorter({}),
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
        telescope_location_picker(title, items, bufnr, opts.picker)
      end
    end)
  end
end

function M.setup()
  local capabilities = require("blink.cmp").get_lsp_capabilities()

  diagnostics.setup()

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
    callback = function(args)
      local bufnr = args.buf
      local client = vim.lsp.get_client_by_id(args.data.client_id)

      if client and (client.name == "ty" or client.name == "ruff") then
        remember_python_workspace_root(client.root_dir)
      end

      if client and client.name == "ruff" then
        client.server_capabilities.hoverProvider = false
      end

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
          postprocess = dedupe_items,
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

  vim.lsp.config("ty", {
    root_dir = function(bufnr, on_dir)
      local root = python_workspace_root(bufnr)

      if root then
        on_dir(root)
      end
    end,
    root_markers = python_root_markers,
    single_file_support = false,
    settings = {
      ty = {
        completions = {
          autoImport = true,
        },
      },
    },
  })

  vim.lsp.config("ruff", {
    root_dir = function(bufnr, on_dir)
      local root = python_workspace_root(bufnr)

      if root then
        on_dir(root)
      end
    end,
    root_markers = python_root_markers,
    single_file_support = false,
    init_options = {
      settings = {
        lineLength = 88,
        lint = {
          select = { "E", "F", "I", "B", "UP" },
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
    "ty",
    "ruff",
    "rust_analyzer",
    "clangd",
    "bashls",
    "ts_ls",
  })
end

return M
