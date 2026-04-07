# AGENTS

## 目的

这个仓库是通过 `stow` 管理的个人 `dotfiles` 真源。修改这里的文件，目标是让 `~/.config`、`~/.local/bin`、shell helper 和编辑器配置都由仓库统一接管，而不是在家目录里手工修补。

## 基本原则

- 这里是 Git 仓库；提交、回退、验证都在仓库内完成。
- 共享配置优先放进仓库；机器绑定内容优先放进本地覆写，不要直接写回共享配置。
- 新增文件后不要手工在 `~/.config` 下创建 symlink；应重新运行 `stow` 让链接由仓库统一管理。
- 如果只是想确认某个家目录文件的真源，先检查它是否是 `stow` 生成的 symlink，再回到仓库内对应路径修改。

## 目录约定

- `shell/.zshrc`: shell helper、alias、默认编辑器和交互函数的唯一真源
- `shell/.config/zsh/local.zsh.example`: 本地覆写示例
- `shell/.local/bin/`: 需要跨机器复用的小工具脚本
- `nvim/.config/nvim/`: Neovim 配置真源
- `yazi/.config/yazi/`: Yazi 配置真源
- `zellij/.config/zellij/`: Zellij 配置真源

## Stow 工作流

- 演练安装用 `./dry-run.sh`
- 正式接管旧配置用 `./backup-and-stow.sh`
- 常规重建链接用 `stow -R -t ~ <package>`
- 如果新增了 `nvim/`、`shell/`、`yazi/`、`zellij/` 下的新文件，修改完成后应重新运行对应的 `stow -R`

## Neovim 约定

- `nvim/.config/nvim/` 是 Neovim 配置真源，不要直接修改 `~/.config/nvim`
- 主题、插件声明、Tree-sitter、lint、formatter 等入口统一在 `nvim/.config/nvim/lua/plugins.lua`
- LSP 逻辑在 `nvim/.config/nvim/lua/config/lsp.lua`
- 全局键位在 `nvim/.config/nvim/lua/config/keymaps.lua`
- 内置速查表在 `nvim/.config/nvim/lua/config/cheatsheet.lua`
- 诊断显示切换逻辑在 `nvim/.config/nvim/lua/config/diagnostics.lua`

运行时边界:

- 插件下载目录是 `~/.local/share/nvim/lazy`
- Tree-sitter parser 安装目录是 `~/.local/share/nvim/treesitter-site/parser`
- 这些运行时产物不纳入仓库；仓库只管理配置和锁文件

当前编辑器工作流约定:

- 用 `lazy.nvim` 管插件，不引入 `LazyVim`
- Tree-sitter parser 不在启动时自动安装；新机器上用 `:TSInstallConfigured`
- 格式化统一走 `conform.nvim`，入口是 `<leader>cf` 和 `:Format`
- 内置快捷键速查表入口是 `<leader>h` 和 `:Cheatsheet`
- LSP、lint、formatter 的外部程序应尽量和终端工作流保持一致，不要为了编辑器再造一套不同命令
- Python 当前用 `ty + ruff` 双 LSP；`ruff` 不再经由 `nvim-lint` 重复上报 diagnostics
- 如果修改了键位、主题、插件结构或外部工具映射，应该同步更新 `README.md` 和 cheatsheet

## Shell / Yazi / Zellij 约定

- `ff`、`frg`、`fh`、`fzj` 等 helper 只改 `shell/.zshrc`
- 当前 CLI 工作流默认用 `nvim` 作为 `ff`、`frg`、Yazi 的编辑器入口；不要无意改回 `hx`
- 如果改了 helper 的行为、默认编辑器或会话选择方式，要一并检查 README 是否需要更新
- 不要把仅当前机器可用的路径、代理、私有 token 直接写进共享配置

## 常用验证

- `zsh -n shell/.zshrc`
- `nvim --headless '+qa'`
- `nvim --headless '+Lazy! sync' '+qa'`
- `./dry-run.sh`
- `./backup-and-stow.sh`

## 文档同步

以下改动通常需要同步文档:

- 新增、删除或重命名 shell helper
- 调整 Neovim 关键键位或用户入口命令
- 调整 Yazi / Zellij 的主工作流入口
- 修改安装方式、依赖或 `stow` 使用方式

优先检查:

- `README.md`
- `AGENTS.md`
- `nvim/.config/nvim/lua/config/cheatsheet.lua`
