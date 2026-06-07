# kubectx-favorites

Show a curated subset of your Kubernetes contexts by default, and toggle to the
full list with a single keypress. A thin zsh wrapper around
[`kubectx`](https://github.com/ahmetb/kubectx) + [`fzf`](https://github.com/junegunn/fzf).

If you have dozens of contexts but live in a handful, `kubectx` makes you fuzzy
through all of them every time. This pins your favorites front-and-center and
keeps the rest one `Tab` away.

## Requirements

- **zsh** (this plugin is zsh-only — it uses zsh array/glob features)
- **kubectx** on `PATH`
- **fzf ≥ 0.45** — the `Tab` toggle reads `$FZF_PROMPT` inside a `transform`
  action, which fzf exposes to child processes from 0.45 onward

## Install

### Manual

```zsh
git clone https://github.com/yhxlele/kubectx-favorites ~/.zsh/kubectx-favorites
echo 'source ~/.zsh/kubectx-favorites/kubectx-favorites.plugin.zsh' >> ~/.zshrc
```

### oh-my-zsh

```zsh
git clone https://github.com/yhxlele/kubectx-favorites \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/kubectx-favorites
# then add `kubectx-favorites` to plugins=(...) in ~/.zshrc
```

### zinit

```zsh
zinit light yhxlele/kubectx-favorites
```

### antidote

```zsh
echo 'yhxlele/kubectx-favorites' >> ~/.zsh_plugins.txt
```

## Configure

Set these in `~/.zshrc` (after loading the plugin is fine — they're read at call time):

```zsh
# Contexts shown by default. Names or glob patterns; order is preserved.
KUBECTX_FAVORITES=(orbstack k3d-akuity-customer 'k3d-akuity-customer-*')
```

| Variable | Default | Purpose |
|---|---|---|
| `KUBECTX_FAVORITES` | *(empty)* | Context names / glob patterns to show by default. Empty ⇒ behaves like plain `kubectx`. |
| `KUBECTX_FAVORITES_PROMPT` | `fav> ` | Prompt shown in favorites mode. Avoid `)` and `+`. |
| `KUBECTX_FAVORITES_ALL_PROMPT` | `all> ` | Prompt shown in all-contexts mode. |
| `KUBECTX_FAVORITES_TOGGLE_KEY` | `tab` | Key that toggles favorites ↔ all. |
| `KUBECTX_FAVORITES_FZF_OPTS` | `--height=40% --reverse` | Extra options passed to `fzf`. |
| `KUBECTX_FAVORITES_OVERRIDE` | *(unset)* | If set, also alias `kubectx` itself to the favorites picker. |
| `KUBECTX_CURRENT_FGCOLOR` / `KUBECTX_CURRENT_BGCOLOR` | *(bold green)* | Color of the current context. Default matches the kubectx Go binary (`FgGreen`+`Bold`). These vars are deprecated in kubectx's Go binary but still honored here as an override. |

## Usage

```zsh
kctx                # fzf picker over your favorites; Tab toggles to all
kctx -a             # picker over ALL contexts (skip favorites)
kctx <name>         # switch directly (passes through to kubectx)
kctx -              # previous context  (passes through)
kctx -c             # current context   (passes through)
kctx -d <name>      # delete context    (passes through)
```

Inside the picker: type to fuzzy-filter, `Tab` to flip between favorites and all
(your typed filter carries across), `⏎` to switch.

With `KUBECTX_FAVORITES_OVERRIDE=1`, all of the above also work as `kubectx …`.

## How it works

- The full list comes from `kubectx` itself (`kubectx | cat`), so it tracks
  whatever kubeconfigs kubectx sees.
- Favorites are resolved by glob-matching that list, de-duplicated and kept in
  the order you wrote them.
- The picker is fed from a favorites file; `Tab` is bound to an fzf `transform`
  that reads the current `$FZF_PROMPT`, then `change-prompt` + `reload`s from
  the all-contexts file (and back).
- The current context is wrapped in ANSI color and rendered with `fzf --ansi`,
  so it stands out the way kubectx highlights it.
- Everything except the no-arg case is delegated straight to `kubectx`, so
  flags, completion, and direct switches behave identically.

## Limitations

- zsh only.
- Rebinds `Tab` inside the picker (normally fzf's multi-select toggle) — fine
  here since this is a single-select switcher.

## License

[MIT](./LICENSE)
