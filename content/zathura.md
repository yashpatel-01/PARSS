# zathura (PDF Viewer)

zathura is the keyboard-driven PDF and document viewer used by PARSS.

## Launching

- Open any PDF file
- Type `zathura file.pdf` or just `z file.pdf`

## Keybindings

### Navigation

| Key | Action |
|-----|--------|
| `j` / `Down` | Scroll down |
| `k` / `Up` | Scroll up |
| `h` / `Left` | Scroll left |
| `l` / `Right` | Scroll right |
| `Ctrl + d/u` | Page down/up |
| `u` | Scroll half-page up (custom) |
| `d` | Scroll half-page down (custom) |
| `Ctrl + u` | Page up |
| `Space` | Page down |
| `Shift + Space` | Page up |
| `gg` | Go to first page |
| `G` | Go to last page |
| `nG` | Go to page n |
### Zoom

| Key | Action |
|-----|--------|
| `+` / `=` | Zoom in |
| `-` | Zoom out |
| `K` | Zoom in (custom) |
| `J` | Zoom out (custom) |
| `a` | Fit to width |
| `s` | Fit to page |
| `D` | Toggle dual-page mode (custom) |
| `r` | Reload document (custom) |
| `R` | Rotate 90° (custom) |
| `i` | Recolor/invert colors (custom) |
| `p` | Print document (custom) |

### Search

| Key | Action |
|-----|--------|
| `/` | Search forward |
| `?` | Search backward |
| `n` | Next match |
| `N` | Previous match |

### Other

| Key | Action |
|-----|--------|
| `Tab` | Show index/outline |
| `o` | Open file |
| `f` | Follow links |
| `F` | Show links |
| `c` | Copy selection |
| `:` | Command mode |
| `q` | Quit |

## Marks

| Key | Action |
|-----|--------|
| `m + letter` | Set mark |
| `' + letter` | Go to mark |

## Configuration

Config file: `~/.config/zathura/zathurarc`

Colors follow the terminal theme by default.

## Supported Formats

- PDF
- PostScript
- DjVu
- Comic book formats (CBZ, CBR)

## Source Code

- [zathura](https://pwmt.org/projects/zathura/)
- zlib License
