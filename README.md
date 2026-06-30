# branchnew

🌐 [English version ↓](#branchnew-english)

> 🤖 **最省事的装法**:把这个仓库、或它的 URL `https://github.com/limin112/branchnew` 丢给 Claude Code,说一句「**帮我装 branchnew**」,它就会照着本 README 的 [安装](#安装) 步骤帮你装好(并会问你要不要 ⌘F 热键 fork)。

在**当前终端**向右劈一个窗格,并在那里把当前的 Claude Code 会话 **fork 一份继续**——于是你立刻得到一个上下文相同的「分身」,就贴在你正在工作的地方。你原来的窗格不动。

一句话:`branchnew` = 「把这个 Claude 会话再 fork 一个分身,放右边」。

```
┌───────────────┬───────────────┐
│  你正在工作的   │  branchnew 开的 │
│  Claude 会话    │  fork 分身      │
│  (原样不动)     │  newBranch[N]   │
└───────────────┴───────────────┘
```

## 用法

```bash
branchnew              # 向右劈窗格 + fork 当前会话,自动命名 newBranch1 / newBranch2 / …
branchnew <name>       # 同上,但把新会话命名为 <name>(原样,不带编号)
branchnew --down       # 向下劈窗格(可与 <name> 组合)
branchnew --help       # 查看帮助
```

例:

```bash
branchnew                    # → newBranch3(自动编号,向右)
branchnew login-fix          # → 会话名 "login-fix"(向右)
branchnew --down 试一下       # → 向下劈,名字 "试一下"
branchnew 试一下别的方案       # 名字可带空格/中文,不用加引号
```

> **在 Claude Code 会话里**:直接打 **`/branchnew`**(或 `/branchnew <名字>`)即可触发同样的 fork——斜杠命令内部就是调 `branchnew`。`install.sh` 会一并把它装到 `~/.claude/commands/`。

## 它做什么

- **精确 fork**:在 Claude Code 会话里运行(`/branchnew`)时,用 `claude --resume <当前session id> --fork-session` 精确 fork **当前这条会话**;在终端直接运行时回退到 `--continue`(最近的会话)。
- **自动命名**:不传名字时,新会话自动叫 `newBranch1`、`newBranch2`……(全局自增编号);传了名字就用你的名字。名字通过 `claude --name` 设置,显示在新会话的**输入框、`/resume` 选择器、终端标题**里,方便区分一堆分支。
- **不改动任何文件或配置**:它只是开一个新的终端视图去跑 `claude`,纯粹的「开窗器」。

## 支持的终端(自动识别)

按优先级自动选择,**无需手动指定**;动作始终是「向右劈一个窗格」,不能劈的退而求其次:

| 终端环境 | 行为 |
|---|---|
| **tmux**(在任意终端里) | `tmux split-window -h`,真·向右分屏 |
| **iTerm2** | 原生 `split vertically`,向右分屏 |
| **Ghostty** | 原生 AppleScript API `split … direction right`,真·向右分屏 |
| **Apple Terminal**(系统自带) | 不支持分屏 → **新开一个窗口**(想真分屏请用 tmux 或 iTerm2) |
| 其它终端(Kitty/Warp/VS Code…) | 无法脚本控制 → 新开一个 Apple Terminal 窗口,并给出提示 |

## 进阶:热键 fork(⌘F / ⌘⇧F)

除了命令行,还可以**按快捷键 fork 当前窗格里那条确切的会话**(精确到 session id,fork-of-a-fork 也对)。

| 快捷键 | 方向 |
|---|---|
| **⌘F** | 向右分屏 |
| **⌘⇧F** | 向下分屏 |

原理:Claude 钩子调用 `branchnew --record` 持续记录「窗格 ↔ 会话」映射;按键时查表、劈窗格、`--resume <id>`。

安装:`./install.sh --hotkey`(会自动写好 Claude 钩子 + 安装对应终端的 fork 脚本)。

| 终端 | 热键机制 | 说明 |
|---|---|---|
| **iTerm2** | 内置 Python API 守护脚本(`claude_fork.py`) | 零依赖,iTerm2 启动即常驻。见 [HOTKEY-FORK.md](HOTKEY-FORK.md) |
| **Ghostty** | `ghostty-fork` 脚本 + Hammerspoon(仅 Ghostty 窗口生效) | 需装 [Hammerspoon](https://www.hammerspoon.org/);Ghostty tip/1.4+ 精确匹配 TTY,1.3.1 按 cwd 匹配 |

<details>
<summary>Ghostty 热键配置步骤</summary>

1. `./install.sh --hotkey` 会安装 `~/.local/bin/ghostty-fork` 并写好 Claude 钩子。
2. 安装 Hammerspoon:`brew install --cask hammerspoon`
3. 写 `~/.hammerspoon/init.lua`(使用 `hs.hotkey.modal` 使热键**仅在 Ghostty 窗口激活时生效**,不影响其他 app 的 ⌘F):
   ```lua
   local ghosttyFilter = hs.window.filter.new("Ghostty")
   local ghosttyKeys = hs.hotkey.modal.new()

   ghosttyKeys:bind({"cmd"}, "F", function()
     hs.task.new(os.getenv("HOME") .. "/.local/bin/ghostty-fork", nil):start()
   end)

   ghosttyKeys:bind({"cmd", "shift"}, "F", function()
     hs.task.new(os.getenv("HOME") .. "/.local/bin/ghostty-fork", nil, {"--down"}):start()
   end)

   ghosttyFilter:subscribe(hs.window.filter.windowFocused, function()
     ghosttyKeys:enter()
   end)

   ghosttyFilter:subscribe(hs.window.filter.windowUnfocused, function()
     ghosttyKeys:exit()
   end)
   ```
4. 启动 Hammerspoon,允许辅助功能权限。
5. Ghostty 配置里禁用默认 ⌘F 和 ⌘⇧F:
   ```
   keybind = super+f=ignore
   keybind = super+shift+f=ignore
   keybind = ctrl+f=start_search
   ```
6. 重启 Ghostty。

</details>

### Windows Terminal / WSL(Ctrl+Shift+F / Ctrl+Shift+Alt+F)

在 WSL + Windows Terminal 里,`branchnew` 用 `wt.exe split-pane` 在当前 tab 内分屏,fork 当前的 OMP 或 Claude Code 会话。OMP 和 Claude Code 都注册了 `/branchnew` 斜杠命令,所以热键发送 `/branchnew\r` 会被 TUI 识别并展开(不会被当成 prompt 吞掉)。

| 快捷键 | 方向 |
|---|---|
| **Ctrl+Shift+F** | 向右分屏 |
| **Ctrl+Shift+Alt+F** | 向下分屏 |

热键通过 [AutoHotkey v2](https://www.autohotkey.com/) 实现(相当于 macOS 的 Hammerspoon),只在 Windows Terminal 窗口聚焦时生效,不影响其他 app。

<details>
<summary>WSL/WT 安装与开机自启</summary>

1. `./install.sh --hotkey` 会安装 `branchnew` 命令、`/branchnew` 斜杠命令(Claude + OMP)、AHK 脚本到 `~/.branchnew/branchnew-hotkey.ahk`。
2. 在 Windows 侧安装 [AutoHotkey v2](https://www.autohotkey.com/)。
3. 运行 AHK 脚本(双击 `\\wsl.localhost\<distro>\home\<user>\.branchnew\branchnew-hotkey.ahk`,或在 WSL 里 `"/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" "$(wslpath -w ~/.branchnew/branchnew-hotkey.ahk)" &`)。
4. **开机自启**:把脚本的快捷方式放进 Windows 启动目录。在 WSL 里执行:
   ```bash
   PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
   AHK_WIN="$(wslpath -w ~/.branchnew/branchnew-hotkey.ahk)"
   STARTUP="$("$PS" -NoProfile -Command '[Environment]::GetFolderPath("Startup")' | tr -d '\r')"
   "$PS" -NoProfile -Command "
   \$ws = New-Object -ComObject WScript.Shell
   \$lnk = \$ws.CreateShortcut('$STARTUP\\branchnew-hotkey.lnk')
   \$lnk.TargetPath = 'C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe'
   \$lnk.Arguments = '\"$AHK_WIN\"'
   \$lnk.Save()
   "
   ```
5. 重启后 AutoHotkey 自动加载脚本,热键开机即用。

> 也可以不用 AutoHotkey,改用 WT 自带的 `sendInput` action(在 `settings.json` 里绑 `Ctrl+Shift+F` → `sendInput "/branchnew\r"`),效果相同。但 WT 没有外部进程控制 pane 的 API,所以这是唯一的热键路径。

</details>

## 安装

**一行装好**(`branchnew` 命令 + `/branchnew` 斜杠命令,无需 clone):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash
```

想**连 ⌘F 热键 fork 一起装**(自动写好 Claude 钩子 + 安装终端对应的 fork 脚本):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
```

> iTerm2 用户还需:开启 Python API、重启 iTerm2 并允许脚本——见 [HOTKEY-FORK.md](HOTKEY-FORK.md)。
> Ghostty 用户还需:装 Hammerspoon + 配置热键——见上方「进阶」折叠。

装完后:在 Claude Code 里打 **`/branchnew`**,或终端里 `branchnew --help`。`~/.local/bin` 不在 PATH 时安装脚本会自动加上(新开终端生效)。

<details>
<summary>从 clone 安装 / 只装命令本体</summary>

```bash
git clone https://github.com/limin112/branchnew.git && cd branchnew
./install.sh            # 基础:branchnew + /branchnew
./install.sh --hotkey   # 再加 iTerm2 热键守护 + 自动写钩子
```

只要 `branchnew` 命令本体(手动):

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/branchnew -o ~/.local/bin/branchnew
chmod +x ~/.local/bin/branchnew
grep -q '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```
</details>

## 会话命名与编号

- **不传名字** → `newBranch<N>`。**N 是全局自增计数器**,持久化在 `~/.local/state/branchnew/counter`(遵循 `$XDG_STATE_HOME`),每次自动命名 +1,永不重复。想重新从头计数就删掉该文件,或写入起始值:
  ```bash
  echo 0 > ~/.local/state/branchnew/counter   # 下一个就是 newBranch1
  ```
- **传名字** → 直接用你给的名字,**不带编号、不消耗计数器**。名字可带空格/中文(脚本用 `$*`,不必加引号)。
- **预览不开窗**:`BRANCHNEW_DRYRUN=1 branchnew [name]` 只打印将要执行的命令(含最终名字)然后退出,不开任何窗口。

## 环境要求

- **macOS**(基于 AppleScript / tmux)。
- 已安装 **Claude Code** CLI,且 `claude` 在 PATH 中。
- 终端被允许运行 AppleScript:首次会弹「自动化(Automation)」授权 → 允许即可
  (系统设置 › 隐私与安全性 › 自动化)。

## 工作原理

`branchnew` 检测 `$TMUX` / `$TERM_PROGRAM` 选择后端,在新窗格/窗口里实际运行:

```bash
# 在 Claude 会话内(有 $CLAUDE_CODE_SESSION_ID):
cd <目录> && claude --resume <session-id> --fork-session --name <名字>

# 在终端直接运行(无 session id):
cd <目录> && claude --continue --fork-session --name <名字>
```

脚本本身**不写死任何个人路径**(只用 `$PWD`、`$@`、`$CLAUDE_CODE_SESSION_ID`),可以原样分享。

## 排错

| 现象 | 原因 / 解决 |
|---|---|
| 报错 `could not open the new view` + AppleScript 错误 | 没给终端「自动化」授权。系统设置 › 隐私与安全性 › 自动化,勾选你的终端控制 iTerm/Terminal/Ghostty。 |
| Apple Terminal 里开成了新窗口而不是分屏 | 正常行为——Terminal 不支持分屏。想真分屏请用 tmux、iTerm2 或 Ghostty。 |
| 新视图里 `claude: command not found` | 新开的 shell 里 `claude` 不在 PATH。先确保 Claude Code 已正确安装。 |
| Ghostty 热键按了没反应 | 检查 Hammerspoon 是否运行且有辅助功能权限;确认 Ghostty 配置里有 `keybind = super+f=ignore`。 |

## License

MIT — 见 [LICENSE](LICENSE)。

---

# branchnew (English)

🌐 [中文版 ↑](#branchnew)

> 🤖 **Easiest install**: hand this repo — or just its URL `https://github.com/limin112/branchnew` — to Claude Code and say *"install branchnew for me."* Claude follows the [Install](#install) steps below (and asks whether you want the ⌘F hotkey fork).

Split the **current terminal** pane to the right and **fork-continue the current Claude Code session** there — instantly giving you a second view with the same context, right next to where you're working. Your original pane is untouched.

In one line: `branchnew` = "fork this Claude session into a clone on the right."

```
┌────────────────┬────────────────┐
│  the session   │  branchnew's   │
│  you're in     │  fork clone    │
│  (untouched)   │  newBranch[N]  │
└────────────────┴────────────────┘
```

## Usage

```bash
branchnew              # split right + fork, auto-named newBranch1 / newBranch2 / …
branchnew <name>       # same, but name the new session <name> (verbatim, no number)
branchnew --down       # split down instead of right (combinable with <name>)
branchnew --help       # show help
```

Examples:

```bash
branchnew                     # → newBranch3 (auto-numbered, right)
branchnew login-fix           # → session named "login-fix" (right)
branchnew --down try ideas    # → split down, named "try ideas"
branchnew try other ideas     # names may contain spaces — no quotes needed
```

> **Inside a Claude Code session**: just type **`/branchnew`** (or `/branchnew <name>`) to trigger the same fork — the slash command runs `branchnew` under the hood. `install.sh` installs it to `~/.claude/commands/`.

## What it does

- **Precise fork**: when run inside a Claude session (`/branchnew`), uses `claude --resume <current session id> --fork-session` to fork **this exact session**; when run directly from the terminal, falls back to `--continue` (most recent session in `$PWD`).
- **Auto-naming**: with no name, the new session is `newBranch1`, `newBranch2`, … (a global incrementing counter); pass a name and it uses yours. The name is set via `claude --name` and shows in the new session's **prompt box, `/resume` picker, and terminal title**.
- **Changes no files or config**: it only opens a new terminal view running `claude` — purely a "window opener."

## Supported terminals (auto-detected)

Chosen automatically by priority, **no flags needed**; the action is always "split a pane to the right," falling back when a terminal can't:

| Terminal | Behavior |
|---|---|
| **tmux** (inside any terminal) | `tmux split-window -h` — a real split to the right |
| **iTerm2** | native `split vertically` to the right |
| **Ghostty** | native AppleScript API `split … direction right` — a real split to the right |
| **Apple Terminal** (built-in) | no split panes → **opens a new window** (use tmux or iTerm2 for a real split) |
| Others (Kitty/Warp/VS Code…) | can't be scripted → opens a new Apple Terminal window, with a notice |

## Advanced: hotkey fork (⌘F / ⌘⇧F)

Besides the command line, you can **press a hotkey to fork the exact session in the current pane** (precise to the session id, so fork-of-a-fork works too).

| Hotkey | Direction |
|---|---|
| **⌘F** | split right |
| **⌘⇧F** | split down |

Claude hooks call `branchnew --record` to continuously record the pane ↔ session mapping; the hotkey looks it up, splits, and runs `--resume <id>`.

Install: `./install.sh --hotkey` (auto-wires hooks + installs the terminal-specific fork script).

| Terminal | Hotkey mechanism | Notes |
|---|---|---|
| **iTerm2** | built-in Python API daemon (`claude_fork.py`) | zero dependencies, runs on iTerm2 launch. See [HOTKEY-FORK.md](HOTKEY-FORK.md) |
| **Ghostty** | `ghostty-fork` script + Hammerspoon (Ghostty-only, other apps unaffected) | requires [Hammerspoon](https://www.hammerspoon.org/); Ghostty tip/1.4+ uses precise TTY matching, 1.3.1 matches by cwd |

<details>
<summary>Ghostty hotkey setup</summary>

1. `./install.sh --hotkey` installs `~/.local/bin/ghostty-fork` and wires the Claude hooks.
2. Install Hammerspoon: `brew install --cask hammerspoon`
3. Write `~/.hammerspoon/init.lua` (uses `hs.hotkey.modal` so hotkeys are **only active when Ghostty is focused** — ⌘F works normally in all other apps):
   ```lua
   local ghosttyFilter = hs.window.filter.new("Ghostty")
   local ghosttyKeys = hs.hotkey.modal.new()

   ghosttyKeys:bind({"cmd"}, "F", function()
     hs.task.new(os.getenv("HOME") .. "/.local/bin/ghostty-fork", nil):start()
   end)

   ghosttyKeys:bind({"cmd", "shift"}, "F", function()
     hs.task.new(os.getenv("HOME") .. "/.local/bin/ghostty-fork", nil, {"--down"}):start()
   end)

   ghosttyFilter:subscribe(hs.window.filter.windowFocused, function()
     ghosttyKeys:enter()
   end)

   ghosttyFilter:subscribe(hs.window.filter.windowUnfocused, function()
     ghosttyKeys:exit()
   end)
   ```
4. Launch Hammerspoon, grant Accessibility permission.
5. Disable Ghostty's default ⌘F and ⌘⇧F in your Ghostty config:
   ```
   keybind = super+f=ignore
   keybind = super+shift+f=ignore
   keybind = ctrl+f=start_search
   ```
6. Restart Ghostty.

</details>

### Windows Terminal / WSL (Ctrl+Shift+F / Ctrl+Shift+Alt+F)

In WSL + Windows Terminal, `branchnew` uses `wt.exe split-pane` to split inside the current tab, forking the active OMP or Claude Code session. Both OMP and Claude Code register `/branchnew` as a slash command, so the hotkey sends `/branchnew\r` and the TUI expands it (it is not swallowed as a raw prompt).

| Hotkey | Direction |
|---|---|
| **Ctrl+Shift+F** | split right |
| **Ctrl+Shift+Alt+F** | split down |

The hotkey is implemented via [AutoHotkey v2](https://www.autohotkey.com/) (the Windows equivalent of Hammerspoon), scoped to Windows Terminal windows only — it won't fire in other apps.

<details>
<summary>WSL/WT setup & boot auto-start</summary>

1. `./install.sh --hotkey` installs the `branchnew` command, the `/branchnew` slash command (Claude + OMP), and the AHK script to `~/.branchnew/branchnew-hotkey.ahk`.
2. Install [AutoHotkey v2](https://www.autohotkey.com/) on Windows.
3. Run the AHK script (double-click `\\wsl.localhost\<distro>\home\<user>\.branchnew\branchnew-hotkey.ahk`, or from WSL: `"/mnt/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" "$(wslpath -w ~/.branchnew/branchnew-hotkey.ahk)" &`).
4. **Boot auto-start**: put a shortcut in the Windows Startup folder. From WSL:
   ```bash
   PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
   AHK_WIN="$(wslpath -w ~/.branchnew/branchnew-hotkey.ahk)"
   STARTUP="$("$PS" -NoProfile -Command '[Environment]::GetFolderPath("Startup")' | tr -d '\r')"
   "$PS" -NoProfile -Command "
   \$ws = New-Object -ComObject WScript.Shell
   \$lnk = \$ws.CreateShortcut('$STARTUP\\branchnew-hotkey.lnk')
   \$lnk.TargetPath = 'C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe'
   \$lnk.Arguments = '\"$AHK_WIN\"'
   \$lnk.Save()
   "
   ```
5. After reboot, AutoHotkey auto-loads the script — the hotkey works on boot.

> You can also skip AutoHotkey and use WT's built-in `sendInput` action (bind `Ctrl+Shift+F` → `sendInput "/branchnew\r"` in `settings.json`) — same effect. But WT has no external pane-control API, so this is the only hotkey path.

</details>

## Install

**One line** (`branchnew` command + `/branchnew` slash command, no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash
```

To **also install the ⌘F hotkey fork** (auto-wires hooks + installs terminal-specific fork script):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
```

> iTerm2 users: enable the Python API + restart iTerm2 — see [HOTKEY-FORK.md](HOTKEY-FORK.md).
> Ghostty users: install Hammerspoon + configure the hotkey — see the "Advanced" section above.

After installing: type **`/branchnew`** in Claude Code, or run `branchnew --help` in a terminal. If `~/.local/bin` isn't on PATH, the installer adds it (takes effect in a new terminal).

<details>
<summary>Install from a clone / just the command itself</summary>

```bash
git clone https://github.com/limin112/branchnew.git && cd branchnew
./install.sh            # base: branchnew + /branchnew
./install.sh --hotkey   # also the iTerm2 hotkey daemon + auto-wired hooks
```

Just the `branchnew` command (manual):

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/branchnew -o ~/.local/bin/branchnew
chmod +x ~/.local/bin/branchnew
grep -q '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```
</details>

## Naming & numbering

- **No name** → `newBranch<N>`. **N is a global incrementing counter** persisted in `~/.local/state/branchnew/counter` (respects `$XDG_STATE_HOME`), +1 on each auto-name, never reused. To start over, delete that file or write a starting value:
  ```bash
  echo 0 > ~/.local/state/branchnew/counter   # next will be newBranch1
  ```
- **With a name** → used verbatim, **no number, counter untouched**. Names may contain spaces/CJK (the script uses `$*`, no quotes needed).
- **Preview without opening anything**: `BRANCHNEW_DRYRUN=1 branchnew [name]` just prints the command it would run (with the final name) and exits.

## Requirements

- **macOS** (built on AppleScript / tmux).
- The **Claude Code** CLI installed, with `claude` on PATH.
- Your terminal allowed to run AppleScript: the first run prompts for **Automation** permission → allow it (System Settings › Privacy & Security › Automation).

## How it works

`branchnew` detects `$TMUX` / `$TERM_PROGRAM` to pick a backend, and in the new pane/window runs:

```bash
# Inside a Claude session ($CLAUDE_CODE_SESSION_ID is set):
cd <dir> && claude --resume <session-id> --fork-session --name <name>

# From the terminal directly (no session id):
cd <dir> && claude --continue --fork-session --name <name>
```

The script hardcodes no personal paths (only `$PWD`, `$@`, `$CLAUDE_CODE_SESSION_ID`), so it's safe to share as-is.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `could not open the new view` + an AppleScript error | Terminal lacks Automation permission. System Settings › Privacy & Security › Automation → allow your terminal to control iTerm/Terminal/Ghostty. |
| Apple Terminal opens a new window instead of splitting | Expected — Terminal has no split panes. Use tmux, iTerm2, or Ghostty for a real split. |
| `claude: command not found` in the new view | `claude` isn't on PATH in the new shell. Make sure Claude Code is installed. |
| Ghostty hotkey doesn't respond | Check Hammerspoon is running with Accessibility permission; confirm `keybind = super+f=ignore` in Ghostty config. |

## License

MIT — see [LICENSE](LICENSE).
