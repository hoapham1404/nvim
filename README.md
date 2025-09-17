# Neovim Configuration (hoapham1404)

A modular Neovim configuration focused on sensible defaults, LSP integrations, and a fast, minimal workflow. This repo contains the personal Neovim setup used by the author; it is organized to be easy to inspect and reuse.

## Highlights

- Lazy-loading plugin management with `lazy.nvim` (configured in `lua/init_lazy.lua`).
- Language Server Protocol (LSP) configurations and per-language tweaks in `lsp/` and `lua/lsp.lua`.
- Opinionated defaults and sensible keymaps in `lua/settings.lua` and `lua/keymaps.lua`.
- Plugin-specific configs in `lua/plugins/` (autocomplete, treesitter, telescope, formatting, etc.).
- After-filetype and plugin tweaks in `after/`.

## Repo layout

- `init.lua` - Main Neovim entry that bootstraps the configuration.
- `lua/` - Primary Lua config folder.
  - `init_lazy.lua` - `lazy.nvim` bootstrap and plugin list.
  - `lsp.lua`, `settings.lua`, `keymaps.lua`, `autocommands.lua` - core configuration.
  - `plugins/` - per-plugin configuration modules (autocomplete, treesitter, formatting, telescope, etc.).
  - `utils/` - small utility helpers used across the config.
- `lsp/` - Additional LSP-specific configurations (e.g. `gopls.lua`, `omnisharp.lua`).
- `after/` - Filetype or plugin-specific autoloads (e.g. `after/ftplugin`).

## Installation (Windows PowerShell)

Warning: these commands will overwrite an existing Neovim config directory. Back up anything you need before running them.

1. Backup existing config (if any):

```powershell
$backup = "$env:LOCALAPPDATA\nvim_backup_$(Get-Date -Format yyyyMMddHHmmss)"
if (Test-Path "$env:LOCALAPPDATA\nvim") { Rename-Item "$env:LOCALAPPDATA\nvim" -NewName $backup }
```

2. Clone this repository into your local Neovim config folder:

```powershell
git clone https://github.com/hoapham1404/nvim.git "$env:LOCALAPPDATA\nvim"
```

3. Start Neovim and install plugins:

```text
nvim
```
Inside Neovim run:
```
:Lazy sync
```

4. (Optional) Restore your backup by renaming the backup folder back to `%LOCALAPPDATA%\nvim`.

## Usage

- Open Neovim as usual: `nvim`.
- Commonly used keymaps and commands are defined in `lua/keymaps.lua`.
- LSP servers are configured under `lsp/` and `lua/plugins/lsp/` (see `lua/lsp.lua` and `lua/plugins/lsp/*`).

## Customization

- Add or change plugin settings in `lua/plugins/`.
- Add language-specific LSP adjustments in `lsp/`.
- Use `init_lazy.lua` to add/remove plugins managed by `lazy.nvim`.

## Notable plugins and features

- Treesitter for syntax highlighting and textobjects.
- Telescope for fuzzy finding and project navigation.
- Autocompletion via `nvim-cmp` and language servers for smart completions.
- Formatting and linting hooks (see `lua/plugins/formatting.lua`).

## Troubleshooting

- If plugins don't load, ensure `lazy.nvim` is present and run `:Lazy sync`.
- Check `:messages` and `:checkhealth` for diagnostic information.
- If Neovim errors on startup, run `nvim --headless -c "lua print(vim.inspect(require('vim')) )"` to get debug output (advanced).

## Development / Contributing

This repo is a personal configuration. Feel free to open issues or submit PRs if you want to suggest improvements; expect small, focused changes.

## License

This configuration contains various plugin configurations and personal settings. The repository does not include third-party plugin source; check each plugin's own license for details.
