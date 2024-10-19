# dual-pane.yazi

[dual-pane.yazi](https://github.com/dawsers/dual-pane.yazi) provides simple
dual pane navigation for [yazi](https://github.com/sxyazi/yazi/), in a similar
fashion to [vifm](https://github.com/vifm/vifm) or [midnight commander](https://midnight-commander.org/).

## Requirements

[yazi](https://github.com/sxyazi/yazi) v0.3.

## Installation

```sh
ya pack -a dawsers/dual-pane
```

Modify your `~/.config/yazi/init.lua` to include:

``` lua
require("dial-pane"):setup()
```

## Usage

The plugin needs to overwrite several key bindings to work well.

Choose your own key bindings or use these in your `~/.config/yazi/keymap.toml`:

``` toml
[manager]
prepend_keymap = [
    { on = "B", run = "plugin --sync dual-pane --args=toggle", desc = "Dual-pane: toggle" },
    { on = "b", run = "plugin --sync dual-pane --args=toggle_zoom", desc = "Dual-pane: toggle zoom" },
    { on = "<Tab>", run = "plugin --sync dual-pane --args=next_pane",  desc = "Dual-pane: switch to the other pane" },
    { on = "[", run = "plugin --sync dual-pane --args='tab_switch -1 --relative'",  desc = "Dual-pane: switch active to previous tab" },
    { on = "]", run = "plugin --sync dual-pane --args='tab_switch 1 --relative'",  desc = "Dual-pane: switch active to next tab" },
    { on = "t", run = "plugin --sync dual-pane --args='tab_create --current'",  desc = "Dual-pane: create a new tab with CWD" },
    { on = "<F5>", run = "plugin --sync dual-pane --args='copy_files --force --follow'",  desc = "Dual-pane: copy selected files from active to inactive pane" },
    { on = "<F6>", run = "plugin --sync dual-pane --args='move_files --force --follow'",  desc = "Dual-pane: move selected files from active to inactive pane" },
]
```

### Commands

| Command                | Arguments                       | Description                                   |
|------------------------|---------------------------------|-----------------------------------------------|
| `toggle`               |                                 | Enable/disable dual pane                      |
| `toggle_zoom`          |                                 | While in dual pane, zoom into the active pane |
| `next_pane`            |                                 | Make the other pane the active one            |
| `tab_switch`           | `[n]` and possibly `--relative` | Same as yazi's `tab_switch`                   |
| `tab_create`           | `[path]`, `--current` or none   | Same as yazi's `tab_create`                   |
| `copy_files`           | `--force`, `--follow`           | Arguments like yazi's `paste`. Copies the selected or hovered file(s) from the current pane to the other one    |
| `move_files`           | `--force`, `--follow`           | Arguments like yazi's `paste`. Moves the selected or hovered file(s) from the current pane to the other one, deleting the original ones   |


## Additional Plugins for Extended Functionality

[fuse-archive.yazi](https://github.com/dawsers/fuse-archive.yazi) if you want to
navigate compressed archives as if they were part of the file system.

[toggle-view.yazi](https://github.com/dawsers/toggle-view.yazi) to quickly
toggle on/off the parent, current or preview panels.
