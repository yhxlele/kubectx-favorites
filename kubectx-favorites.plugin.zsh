#!/usr/bin/env zsh
#
# kubectx-favorites — show a curated subset of kube contexts by default,
# and toggle to the full list with a keypress. Thin wrapper around
# `kubectx` + `fzf`.
#
# Provides the `kctx` command. Set KUBECTX_FAVORITES_OVERRIDE=1 to also
# shadow `kubectx` itself so your muscle memory keeps working.
#
# Requirements: zsh, kubectx, fzf >= 0.45 (the Tab toggle uses $FZF_PROMPT,
# which fzf exposes to `transform` actions since 0.45).
#
# https://github.com/yhxlele/kubectx-favorites

# ---- configuration (override in ~/.zshrc) -----------------------------------

# Contexts to show by default. Each entry is a name or a glob pattern, e.g.
#   KUBECTX_FAVORITES=(orbstack k3d-akuity-customer 'k3d-akuity-customer-*')
# If empty, the plugin transparently defers to plain `kubectx`.
typeset -ga KUBECTX_FAVORITES

# Prompt strings shown for each mode (avoid the characters ')' and '+').
: ${KUBECTX_FAVORITES_PROMPT='fav> '}
: ${KUBECTX_FAVORITES_ALL_PROMPT='all> '}

# Key that toggles favorites <-> all inside the picker.
: ${KUBECTX_FAVORITES_TOGGLE_KEY=tab}

# Extra options passed to fzf (word-split on spaces).
: ${KUBECTX_FAVORITES_FZF_OPTS='--height=40% --reverse'}

# KUBECTX_FAVORITES_OVERRIDE=1  -> also define `kubectx` as an alias of `kctx`.

# ---- internals --------------------------------------------------------------

# Full context list, straight from kubectx's own enumeration (so it tracks
# whatever kubeconfigs kubectx sees). Piping strips color -> plain newlines.
_kctx_all_contexts() {
  command kubectx 2>/dev/null | command cat
}

# Favorites resolved against the live context list, glob-aware, de-duplicated,
# order-preserving (favorites order first, then match order within each).
_kctx_favorites() {
  emulate -L zsh
  local -a all matched
  all=("${(@f)$(_kctx_all_contexts)}")
  local pat ctx
  for pat in "${KUBECTX_FAVORITES[@]}"; do
    for ctx in "${all[@]}"; do
      [[ -n "$ctx" && "$ctx" == ${~pat} && ${matched[(Ie)$ctx]} -eq 0 ]] && matched+=("$ctx")
    done
  done
  print -l "${matched[@]}"
}

# ---- command ----------------------------------------------------------------

kctx() {
  emulate -L zsh

  if ! command -v kubectx >/dev/null 2>&1; then
    print -u2 "kubectx-favorites: 'kubectx' not found on PATH"
    return 127
  fi

  # `kctx -a` / `--all`: full picker over every context.
  case "$1" in
    -a|--all) shift; command kubectx "$@"; return ;;
  esac

  # Any explicit args (a name, `-`, `-c`, `-d`, completion, ...): pass through.
  if (( $# > 0 )); then
    command kubectx "$@"
    return
  fi

  # No fzf, or no favorites resolved: behave exactly like plain kubectx.
  if ! command -v fzf >/dev/null 2>&1; then
    command kubectx
    return
  fi
  local -a favs
  favs=("${(@f)$(_kctx_favorites)}")
  if (( ${#favs} == 0 )) || [[ -z "${favs[1]}" ]]; then
    command kubectx
    return
  fi

  # Two source files; Tab swaps which one feeds the picker (and flips the prompt
  # as a visual cue). $FZF_PROMPT is read in the transform to decide direction.
  local favfile allfile choice
  favfile=$(mktemp) || return
  allfile=$(mktemp) || { rm -f "$favfile"; return; }
  print -l "${favs[@]}" > "$favfile"
  _kctx_all_contexts    > "$allfile"

  local fp="$KUBECTX_FAVORITES_PROMPT" ap="$KUBECTX_FAVORITES_ALL_PROMPT"
  local key="$KUBECTX_FAVORITES_TOGGLE_KEY"
  local bind="${key}:transform:[ \"\$FZF_PROMPT\" = '${fp}' ] && echo 'change-prompt(${ap})+reload(cat \"${allfile}\")' || echo 'change-prompt(${fp})+reload(cat \"${favfile}\")'"

  choice=$(fzf ${=KUBECTX_FAVORITES_FZF_OPTS} \
    --prompt="$fp" \
    --header="⏎ switch · ${key}: favorites ↔ all" \
    --bind "$bind" \
    < "$favfile")
  rm -f "$favfile" "$allfile"

  [[ -n "$choice" ]] && command kubectx "$choice"
}

# ---- optional integrations --------------------------------------------------

# Route `kubectx` through the favorites picker when KUBECTX_FAVORITES_OVERRIDE
# is set. The decision is deferred to the first prompt so the env var can be set
# either before OR after this file is sourced; `kubectx` is left completely
# untouched when the var is unset.
_kctx_maybe_override() {
  emulate -L zsh
  if [[ -n "$KUBECTX_FAVORITES_OVERRIDE" ]] && (( ! $+functions[kubectx] )); then
    kubectx() { kctx "$@"; }
  fi
  add-zsh-hook -d precmd _kctx_maybe_override 2>/dev/null
  unfunction _kctx_maybe_override 2>/dev/null
}
autoload -Uz add-zsh-hook
if (( $+functions[add-zsh-hook] )); then
  add-zsh-hook precmd _kctx_maybe_override
else
  # Very old zsh without add-zsh-hook: fall back to a load-time decision.
  [[ -n "$KUBECTX_FAVORITES_OVERRIDE" ]] && kubectx() { kctx "$@"; }
  unfunction _kctx_maybe_override 2>/dev/null
fi

# Borrow kubectx's completion for kctx, if completion is initialized.
if (( $+functions[compdef] )); then
  compdef kctx=kubectx 2>/dev/null
fi
