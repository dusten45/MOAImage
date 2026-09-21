if [[ -z "${VIRTUAL_ENV:-}" && -f /venv/main/bin/activate ]]; then
    source /venv/main/bin/activate
fi

# Match Vast's normal starting location if the shell begins in root's home.
if [[ "$PWD" == "$HOME" && -d /workspace ]]; then
    cd /workspace
fi

_moa_sync_tmux_env() {
    [[ -n "${TMUX:-}" ]] || return 0

    local name statement
    for name in DISPLAY XAUTHORITY SSH_AUTH_SOCK; do
        statement="$(tmux show-environment -s "$name" 2>/dev/null)" || continue
        [[ -n "$statement" ]] && eval "$statement"
    done
}

if [[ -n "${TMUX:-}" ]]; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _moa_sync_tmux_env
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        case ";${PROMPT_COMMAND:-};" in
            *";_moa_sync_tmux_env;"*) ;;
            *) PROMPT_COMMAND="_moa_sync_tmux_env${PROMPT_COMMAND:+;${PROMPT_COMMAND}}" ;;
        esac
    fi
    _moa_sync_tmux_env
fi

clip() {
    if (( $# != 1 )); then
        printf 'usage: clip <file>\n' >&2
        return 2
    fi

    _moa_sync_tmux_env

    if [[ -z "${DISPLAY:-}" ]]; then
        printf 'DISPLAY is empty. Connect with X11 forwarding, for example: ssh -X ...\n' >&2
        return 1
    fi

    xclip -selection clipboard < "$1"
}

tmuxreload() {
    tmux source-file /etc/tmux.conf
    [[ -f "$HOME/.tmux.conf" ]] && tmux source-file "$HOME/.tmux.conf"
}

alias ll='ls -lah --color=auto'
alias gs='git status --short --branch'
alias gl='git log --oneline --decorate -20'
