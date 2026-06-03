# AI account switcher wrappers.
# Put this near the top of ~/.zshrc so local account wrappers win over Homebrew and /usr/local/bin.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Optional explicit hub path for the zsh cursor wrapper.
export CURSOR_ACCOUNT_HUB_DIR="$HOME/.config/cursor-account-hub"
