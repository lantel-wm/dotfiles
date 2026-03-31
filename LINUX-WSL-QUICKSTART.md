# Linux / WSL 最短安装清单

适用场景:

- Ubuntu / Debian
- WSL

## 1. 安装基础依赖

```bash
sudo apt update
sudo apt install -y git stow zsh curl wget
```

## 2. 克隆仓库

```bash
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles
```

## 3. 装常用工具并补齐 `bat` / `fd` 兼容名

```bash
./bootstrap-ubuntu-wsl.sh
```

## 4. 如果是全新机器

```bash
./install.sh
```

## 5. 如果这台机器已经有旧配置

先演练:

```bash
./dry-run.sh
```

再接管:

```bash
./backup-and-stow.sh
```

## 6. 可选

把 `zsh` 设为默认 shell:

```bash
chsh -s "$(command -v zsh)"
```

WSL 本地覆盖示例:

```bash
mkdir -p ~/.config/zsh
cp ~/dotfiles/shell/.config/zsh/local.zsh.example ~/.config/zsh/local.zsh
```

常见 WSL 本地项:

```bash
export BROWSER=wslview
```
