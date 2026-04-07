local M = {}

local virtual_text = {
  spacing = 2,
  source = "if_many",
}

M.virtual_text_enabled = true

function M.setup()
  vim.diagnostic.config({
    severity_sort = true,
    underline = true,
    update_in_insert = false,
    virtual_text = M.virtual_text_enabled and vim.deepcopy(virtual_text) or false,
    float = {
      border = "rounded",
      source = "if_many",
    },
  })
end

function M.toggle_virtual_text()
  M.virtual_text_enabled = not M.virtual_text_enabled

  vim.diagnostic.config({
    virtual_text = M.virtual_text_enabled and vim.deepcopy(virtual_text) or false,
  })

  vim.notify(
    string.format("Diagnostic virtual text %s", M.virtual_text_enabled and "enabled" or "disabled"),
    vim.log.levels.INFO
  )
end

return M
