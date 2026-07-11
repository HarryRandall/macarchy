# Homebrew is installed in different locations on Apple Silicon, Intel and
# custom setups. Ask Homebrew for its environment instead of fixing one path.
_macarchy_brew="$(command -v brew 2>/dev/null || true)"
if [[ -z "$_macarchy_brew" ]]; then
    for _macarchy_candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$_macarchy_candidate" ]]; then
            _macarchy_brew="$_macarchy_candidate"
            break
        fi
    done
fi

if [[ -n "$_macarchy_brew" ]]; then
    eval "$("$_macarchy_brew" shellenv)"
fi

unset _macarchy_brew _macarchy_candidate
