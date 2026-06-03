export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"

typeset -gU path fpath
path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
export PATH FPATH

export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
