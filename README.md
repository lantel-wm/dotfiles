# dotfiles

使用 `git + stow` 管理的个人配置，按工具拆成独立包，便于在 macOS、Linux、WSL 上按需同步。

## 包列表

- `shell`: `zsh`、`fish`、`~/.local/bin`
- `git`: Git 全局配置
- `conda`: `conda` 默认行为
- `helix`: Helix 配置
- `nvim`: Neovim 配置
- `zellij`: Zellij 配置
- `yazi`: Yazi 配置
- `ghostty-macos`: Ghostty，仅 macOS 使用

说明:

- `yazi` 包默认去掉了 macOS 专用的 `mactag` 插件，保证 Linux / WSL 也能直接用。
- 如果你还想在 macOS 上保留 `mactag`，建议放到 `~/.config/yazi` 的本地手工覆盖里，不进 Git。

## 依赖

- `git`
- `stow`

macOS:

```bash
brew install stow
```

Ubuntu / Debian / WSL:

```bash
sudo apt install stow
```

更完整的 Ubuntu / WSL 初始化可以直接运行:

```bash
./bootstrap-ubuntu-wsl.sh
```

最短步骤见 [LINUX-WSL-QUICKSTART.md](./LINUX-WSL-QUICKSTART.md)。

## 初始化

```bash
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

Ubuntu / WSL 推荐顺序:

```bash
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles
./bootstrap-ubuntu-wsl.sh
./dry-run.sh
./backup-and-stow.sh
```

`install.sh` 默认安装:

- 所有通用包: `shell git conda helix nvim zellij yazi`
- macOS 额外安装: `ghostty-macos`

也可以手动执行:

```bash
stow -R -d ~/dotfiles -t ~ shell git conda helix nvim zellij yazi
stow -R -d ~/dotfiles -t ~ ghostty-macos
```

拉取仓库更新后，如有新增文件或链接，直接重新运行:

```bash
./install.sh
```

或者手动:

```bash
stow -R -d ~/dotfiles -t ~ shell git conda helix nvim zellij yazi
```

## 首次接管现有配置

如果目标机已经有同名配置文件，不要直接运行 `stow`。先做演练:

```bash
./dry-run.sh
```

确认没问题后，再运行:

```bash
./backup-and-stow.sh
```

这个脚本会:

- 先把与本仓库冲突的现有文件移动到一个时间戳备份目录
- 再执行 `stow -R`
- 不会删除备份

## 本地覆盖

仓库里不保存明显的机器绑定配置。需要本机特化时，创建以下文件之一:

- `~/.config/zsh/local.zsh`
- `~/.config/zsh/login.local.zsh`

可参考 `shell/.config/zsh/local.zsh.example`。
登录 shell 专用覆盖可参考 `shell/.config/zsh/login.local.zsh.example`。

适合放进本地覆盖的内容:

- 代理
- 本地编译的 `zellij` 路径
- `p10k` / 其他只想本机使用的 prompt 配置
- `MATLAB`、`duckdb` 等只在部分机器存在的路径
- 任何不想进入 Git 的环境变量

WSL 常见本地覆盖:

- `export BROWSER=wslview`
- 任何只想在 WSL 中生效的代理配置
- Windows 互操作命令相关的 alias 或函数

## Neovim 包

`nvim/` 现在是一个不依赖 `LazyVim` 的极简自配方案，继续通过 `stow` 接管到 `~/.config/nvim`。

- 插件管理: `lazy.nvim`
- 主题: `catppuccin`（当前 flavour: `macchiato`）
- 语法树: `nvim-treesitter`
- LSP: `nvim-lspconfig`
- 补全: `blink.cmp`（锁在 `1.*`，避免误跟进 V2）
- Git 改动: `gitsigns.nvim`
- 格式化: `conform.nvim`
- lint: `nvim-lint`
- 注释: `Comment.nvim` + `nvim-ts-context-commentstring`
- 成对符号: `mini.pairs`

常用入口:

- `<leader>h` 或 `:Cheatsheet`: 打开或关闭内置快捷键速查表
- `:TSInstallConfigured`: 在新机器上安装这套配置声明的 Tree-sitter parsers
- `<leader>cf` 或 `:Format`: 走 `conform.nvim` 统一格式化当前 buffer

输入补全补充:

- 空的 `() [] {}` 中间按 `<CR>` 会展开成带缩进的三行结构
- Python 文件里输入 `"""` 会自动补成成对的 triple quotes

语言默认覆盖:

- Python: `basedpyright` + `ruff`
- Rust: `rust-analyzer`（保存检查走 `clippy`）
- Shell: `bashls`，`sh/bash` 额外走 `shellcheck`
- C++: `clangd --background-index --clang-tidy`
- TypeScript: `ts_ls` + `eslint`

推荐系统依赖:

- `nvim >= 0.12`
- `git`、`curl`、`tree-sitter-cli`、可用的 C 编译器
- `basedpyright`、`ruff`
- `rust-analyzer`
- `clangd`
- `bash-language-server`
- `shellcheck`
- `typescript-language-server`
- `eslint` 或 `eslint_d`
