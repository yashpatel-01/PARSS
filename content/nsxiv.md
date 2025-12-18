# nsxiv (Image Viewer)

nsxiv (Neo Simple X Image Viewer) is the image viewer used by PARSS.

## Launching

- Open any image file
- Type `nsxiv image.png` in terminal
- In lf, press `T` for thumbnail mode

## Keybindings

### Navigation

| Key | Action |
|-----|--------|
| `n` / `Space` | Next image |
| `p` / `Backspace` | Previous image |
| `g` | First image |
| `G` | Last image |
| `[count]g` | Go to image number |

### View

| Key | Action |
|-----|--------|
| `+` / `=` | Zoom in |
| `-` | Zoom out |
| `0` | Fit to window |
| `w` | Fit width |
| `e` | Fit height |
| `h/j/k/l` | Pan image |
| `H/J/K/L` | Pan image (fast) |
| `|` | Flip horizontal |
| `_` | Flip vertical |
| `<` / `>` | Rotate left/right 90° |
| `?` | Rotate 180° |
| `a` | Toggle anti-aliasing |
| `A` | Toggle animation |

### Selection & Thumbnails

| Key | Action |
|-----|--------|
| `t` | Toggle thumbnail mode |
| `m` | Mark image |
| `M` | Mark all |
| `Ctrl + m` | Reverse marks |
| `N` | Go to next marked |
| `P` | Go to previous marked |

### Actions

| Key | Action |
|-----|--------|
| `Enter` | Run key-handler script |
| `Ctrl + x` | Run key-handler script |
| `r` | Reload image |
| `R` | Reload all thumbnails |
| `s` | Slideshow |
| `i` | Show image info |
| `q` | Quit |

## Key Handler

Press `Ctrl + x` or `Enter` to open key handler, then press:

| Key | Action |
|-----|--------|
| `w` | Set image as wallpaper |
| `c` | Copy image to bookmarked directory |
| `m` | Move image to bookmarked directory |
| `r` | Rotate 90° clockwise (and save) |
| `R` | Rotate 90° counter-clockwise (and save) |
| `f` | Flip image horizontally (and save) |
| `y` | Copy filename to clipboard |
| `Y` | Copy full path to clipboard |
| `d` | Delete image (with confirmation) |
| `g` | Open in GIMP |
| `i` | Show image info (mediainfo) |

## Wallpaper

In lf, select an image and press `b` to set it as wallpaper using `setbg`.

## Thumbnail Mode

- Press `t` to toggle thumbnail view
- Navigate with `h/j/k/l`
- Press `Enter` to view selected image

## Configuration

Key handler: `~/.config/nsxiv/exec/key-handler`

Quick access: `cfX` in terminal

## Source Code

- [nsxiv](https://codeberg.org/nsxiv/nsxiv)
- GPL License
