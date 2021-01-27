# LARBS Keybindings, Shortcuts & Aliases Reference

**Mod Key = Super/Windows Key**

## DWM Window Manager Keybindings

### Navigation & Window Focus
| Keybinding | Action |
|------------|--------|
| `Mod+j` | Focus next window in stack |
| `Mod+k` | Focus previous window in stack |
| `Mod+v` | Focus master window |
| `Mod+Shift+j` | Move window down in stack |
| `Mod+Shift+k` | Move window up in stack |
| `Mod+h` | Shrink master area |
| `Mod+l` | Expand master area |
| `Mod+space` | Move window to/from master |
| `Mod+Tab` | Toggle between last two tags |

### Window Management
| Keybinding | Action |
|------------|--------|
| `Mod+q` | Kill/close window |
| `Mod+Shift+q` | System actions (shutdown/reboot) |
| `Mod+Shift+space` | Toggle floating |
| `Mod+f` | Toggle fullscreen |
| `Mod+s` | Make window sticky (show on all tags) |
| `Mod+o` | Increase master windows count |
| `Mod+Shift+o` | Decrease master windows count |

### Layouts
| Keybinding | Layout |
|------------|--------|
| `Mod+t` | Tiling layout |
| `Mod+Shift+t` | Bottom stack layout |
| `Mod+y` | Spiral layout |
| `Mod+Shift+y` | Dwindle layout |
| `Mod+u` | Deck layout |
| `Mod+Shift+u` | Monocle (fullscreen) layout |
| `Mod+i` | Centered master layout |
| `Mod+Shift+i` | Centered floating master |
| `Mod+Shift+f` | Floating layout |

### Tags (Workspaces)
| Keybinding | Action |
|------------|--------|
| `Mod+1-9` | Switch to tag 1-9 |
| `Mod+Shift+1-9` | Move window to tag 1-9 |
| `Mod+0` | View all tags at once |
| `Mod+Shift+0` | Tag window to all tags |
| `Mod+g` | Go to previous tag |
| `Mod+;` | Go to next tag |
| `Mod+Shift+g` | Move window to previous tag |
| `Mod+Shift+;` | Move window to next tag |
| `Mod+Page_Up` | Previous tag |
| `Mod+Page_Down` | Next tag |

### Gaps & Appearance
| Keybinding | Action |
|------------|--------|
| `Mod+z` | Increase gaps |
| `Mod+x` | Decrease gaps |
| `Mod+a` | Toggle gaps on/off |
| `Mod+Shift+a` | Reset gaps to default |
| `Mod+Shift+'` | Toggle smart gaps |
| `Mod+b` | Toggle status bar |

### Applications
| Keybinding | Application |
|------------|-------------|
| `Mod+Return` | Terminal (st) |
| `Mod+Shift+Return` | Scratchpad terminal |
| `Mod+d` | dmenu (run launcher) |
| `Mod+Shift+d` | passmenu (password manager) |
| `Mod+w` | Web browser (LibreWolf) |
| `Mod+Shift+w` | Network manager (nmtui) |
| `Mod+r` | File manager (lf) |
| `Mod+Shift+r` | System monitor (htop) |
| `Mod+e` | Email (neomutt) |
| `Mod+Shift+e` | Address book (abook) |
| `Mod+m` | Music player (ncmpcpp) |
| `Mod+n` | Notes (vimwiki) |
| `Mod+Shift+n` | RSS reader (newsboat) |
| `Mod+c` | Chat (profanity XMPP) |
| `Mod+'` | Calculator scratchpad |
| `Mod+grave` | Unicode picker (dmenuunicode) |

### Music Control (MPD)
| Keybinding | Action |
|------------|--------|
| `Mod+p` | Toggle play/pause |
| `Mod+Shift+p` | Pause all |
| `Mod+,` | Previous track |
| `Mod+.` | Next track |
| `Mod+Shift+,` | Seek to beginning |
| `Mod+Shift+.` | Toggle repeat |
| `Mod+[` | Seek -10 seconds |
| `Mod+Shift+[` | Seek -60 seconds |
| `Mod+]` | Seek +10 seconds |
| `Mod+Shift+]` | Seek +60 seconds |

### Audio Control
| Keybinding | Action |
|------------|--------|
| `Mod+-` | Volume down 5% |
| `Mod+Shift+-` | Volume down 15% |
| `Mod+=` | Volume up 5% |
| `Mod+Shift+=` | Volume up 15% |
| `Mod+Shift+m` | Toggle mute |

### Function Keys
| Keybinding | Action |
|------------|--------|
| `Mod+F1` | Show keybindings guide |
| `Mod+F2` | Tutorial videos |
| `Mod+F3` | Display/monitor settings |
| `Mod+F4` | Audio mixer (pulsemixer) |
| `Mod+F5` | Reload Xresources |
| `Mod+F6` | Toggle Tor |
| `Mod+F7` | Toggle transmission daemon |
| `Mod+F8` | Sync email (mailsync) |
| `Mod+F9` | Mount drives (mounter) |
| `Mod+F10` | Unmount drives (unmounter) |
| `Mod+F11` | Webcam preview |
| `Mod+F12` | Reload keyboard remaps |

### Screenshots & Recording
| Keybinding | Action |
|------------|--------|
| `Print` | Screenshot full screen |
| `Shift+Print` | Screenshot selection (maimpick) |
| `Mod+Print` | Start recording (dmenurecord) |
| `Mod+Shift+Print` | Stop recording |
| `Mod+Delete` | Kill recording |
| `Mod+Scroll_Lock` | Toggle screenkey (show keypresses) |
| `Mod+Insert` | Paste snippet from dmenu |

### Multi-Monitor
| Keybinding | Action |
|------------|--------|
| `Mod+Left` | Focus left monitor |
| `Mod+Right` | Focus right monitor |
| `Mod+Shift+Left` | Move window to left monitor |
| `Mod+Shift+Right` | Move window to right monitor |

### System
| Keybinding | Action |
|------------|--------|
| `Mod+Backspace` | System menu (sysact) |
| `Mod+Shift+Backspace` | System menu (sysact) |

---

## Shell Aliases (from aliasrc)

### Command Improvements
```bash
alias cp="cp -iv"           # Interactive, verbose copy
alias mv="mv -iv"           # Interactive, verbose move
alias rm="rm -vI"           # Verbose, prompt if >3 files
alias bc="bc -ql"           # Better calculator
alias rsync="rsync -vrPlu"  # Verbose, recursive, progress
alias mkd="mkdir -pv"       # Create dirs with parents
```

### Colorized Commands
```bash
alias ls="ls -hN --color=auto --group-directories-first"
alias grep="grep --color=auto"
alias diff="diff --color=auto"
alias ip="ip -color=auto"
```

### Downloads & Media
```bash
alias yt="yt-dlp --embed-metadata -i"  # Download video
alias yta="yt -x -f bestaudio/best"    # Download audio only
alias ytt="yt --skip-download --write-thumbnail"  # Download thumbnail
alias ffmpeg="ffmpeg -hide_banner"     # Cleaner ffmpeg output
```

### Short Commands
```bash
alias ka="killall"          # Kill all processes by name
alias g="git"               # Short git
alias sdn="shutdown -h now" # Quick shutdown
alias e='$EDITOR'           # Open editor
alias v='$EDITOR'           # Open editor
alias p="pacman"            # Short pacman
alias z="zathura"           # PDF viewer
alias lf="lfub"             # File manager with ueberzug
alias ref='shortcuts >/dev/null; source shortcutrc'  # Reload shortcuts
```

### Sudo Aliases (no sudo needed)
```bash
# These commands automatically use sudo:
mount, umount, sv, pacman, updatedb, su, shutdown, poweroff, reboot
```

### Special Functions
```bash
se()  # Script editor - fuzzy find and edit scripts in ~/.local/bin
```

---

## Shell Shortcuts (created by `shortcuts` command)

### Directory Shortcuts (used in shell and lf)
These are typically defined in `~/.config/shell/bm-dirs`:
```
h  ~                    # Home directory
d  ~/Documents          # Documents
D  ~/Downloads          # Downloads
m  ~/Music              # Music
pp ~/Pictures           # Pictures
vv ~/Videos             # Videos
cf ~/.config            # Config directory
sc ~/.local/bin         # Scripts directory
mn /mnt                 # Mount point
```

### File Shortcuts
Defined in `~/.config/shell/bm-files`:
```
cfz ~/.config/zsh/.zshrc           # Zsh config
cfa ~/.config/shell/aliasrc         # Aliases
cfv ~/.config/nvim/init.vim         # Neovim config
cfm ~/.config/mutt/muttrc           # Mutt config
```

---

## LF File Manager Shortcuts

### Navigation
```
h/l     - Go up/down in directory tree
j/k     - Move up/down in file list
gg/G    - Go to top/bottom
```

### File Operations
```
<Enter> - Open file
d       - Cut (mark for move)
y       - Copy (yank)
p       - Paste
<Del>   - Delete
c       - Clear marks
```

### Quick Navigate (using shortcuts)
```
gh      - Go to home (~)
gd      - Go to Documents
gD      - Go to Downloads
gm      - Go to Music
...etc
```

---

## Terminal-Specific

### Zsh Vi Mode
```
Esc     - Enter normal mode
i/a     - Insert mode
v       - Visual mode
/       - Search
n/N     - Next/previous search result
```

---

## Important Scripts in ~/.local/bin

| Script | Purpose |
|--------|---------|
| `shortcuts` | Generate shell/lf shortcuts from bookmarks |
| `linkhandler` | Open URLs/files with appropriate program |
| `dmenurecord` | Screen recording menu |
| `maimpick` | Screenshot with selection |
| `displayselect` | Multi-monitor setup |
| `mounter/unmounter` | Mount/unmount drives |
| `mailsync` | Sync email (mbsync) |
| `sysact` | System actions (shutdown/reboot/etc) |
| `lfub` | LF with ueberzug image previews |
| `ducksearch` | DuckDuckGo search from terminal |
| `compiler` | Universal compile script |
| `torwrap` | Run command through Tor |

---

## Environment Variables to Know

```bash
$EDITOR     - Default text editor (nvim)
$TERMINAL   - Default terminal (st)
$BROWSER    - Default browser (librewolf)
$READER     - PDF reader (zathura)
$FILE       - File manager (lf)
```

---

## Testing Instructions

To test if keybindings work:
1. Press `Mod+Return` - Should open terminal
2. Press `Mod+d` - Should open dmenu
3. Press `Mod+j/k` - Should cycle windows
4. Press `Mod+1` - Should switch to tag 1
5. Press `Mod+Shift+q` - Should show system menu

To test aliases:
```bash
# In terminal
ls      # Should show colored output
g status  # Should run git status
ka firefox  # Should kill all firefox processes
```

To test shortcuts:
```bash
# In terminal
cd d    # Should fail (not yet sourced)
ref     # Reload shortcuts
cd d    # Should go to ~/Documents
```
