# Vast base images may expose /venv/main/bin before the system ncurses tools.
# Keep the MOA tools and /usr/bin ahead of it so `infocmp` always uses the
# system terminfo database that contains alacritty and xterm-kitty.
typeset -U path
path=(
    /root/.cargo/bin
    /root/.kilo/bin
    /opt/moa-python/bin
    /usr/local/sbin
    /usr/local/bin
    /usr/sbin
    /usr/bin
    /sbin
    /bin
    $path
)
export PATH

unset TERMINFO
export TERMINFO_DIRS=/etc/terminfo:/lib/terminfo:/usr/share/terminfo
alias infocmp=/usr/bin/infocmp

_moa_sync_tmux_env() {
    [[ -n "${TMUX:-}" ]] || return 0

    local name statement
    for name in DISPLAY XAUTHORITY SSH_AUTH_SOCK; do
        statement="$(tmux show-environment -s "$name" 2>/dev/null)" || continue
        eval "$statement"
    done
}

if [[ -n "${TMUX:-}" ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _moa_sync_tmux_env
    _moa_sync_tmux_env
fi

clip() {
    if (( $# != 1 )); then
        print -u2 "usage: clip <file>"
        return 2
    fi

    _moa_sync_tmux_env

    if [[ -z "${DISPLAY:-}" ]]; then
        print -u2 "DISPLAY is empty. Connect with X11 forwarding, for example: ssh -X ..."
        return 1
    fi

    xclip -selection clipboard < "$1"
}

termcheck() {
    print "TERM=${TERM:-<unset>}"
    print "infocmp=/usr/bin/infocmp"
    if [[ -z "${TERM:-}" ]]; then
        print -u2 "terminfo: TERM is unset"
        return 1
    fi
    if /usr/bin/infocmp "$TERM" >/dev/null 2>&1; then
        print "terminfo: OK"
    else
        print -u2 "terminfo: missing for $TERM"
        return 1
    fi
    if [[ -n "${TMUX:-}" ]]; then
        tmux info 2>/dev/null | grep -E '(^|[[:space:]])(RGB|Ms):' || true
    fi
}

tmuxreload() {
    tmux source-file /etc/tmux.conf
    [[ -f "$HOME/.tmux.conf" ]] && tmux source-file "$HOME/.tmux.conf"
}

alias ll='ls -lah --color=auto'
alias gs='git status --short --branch'
alias gl='git log --oneline --decorate -20'
