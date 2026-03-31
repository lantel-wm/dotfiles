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
stow -d ~/dotfiles -t ~ shell git conda helix nvim zellij yazi
stow -d ~/dotfiles -t ~ ghostty-macos
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
- 再执行 `stow`
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
