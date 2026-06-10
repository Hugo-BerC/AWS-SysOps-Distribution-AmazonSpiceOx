# AmazonSpiceOx root shell defaults.

export LANG="${LANG:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"
export LC_COLLATE="${LC_COLLATE:-en_US.UTF-8}"
export TERM="${TERM:-xterm-256color}"
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"

case "$-" in
    *i*)
        shopt -s checkwinsize 2>/dev/null || true
        shopt -s histappend 2>/dev/null || true

        dune_reset='\[\033[0m\]'
        dune_gold='\[\033[38;5;220m\]'
        dune_spice='\[\033[38;5;214m\]'
        dune_sand='\[\033[38;5;180m\]'
        dune_dim='\[\033[38;5;244m\]'
        dune_blue='\[\033[38;5;67m\]'

        PS1="${dune_dim}[${dune_sand}\u${dune_dim}@${dune_gold}\h${dune_dim}:${dune_blue}\w${dune_dim}]${dune_spice}\\$ ${dune_reset}"

        alias ll='ls -alF --color=auto'
        alias la='ls -A --color=auto'
        alias l='ls -CF --color=auto'
        alias grep='grep --color=auto'
        alias cls='clear'
        ;;
esac

if [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi
