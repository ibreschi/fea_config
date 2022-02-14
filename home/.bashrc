# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=100000
HISTFILESIZE=40000000
PROMPT_COMMAND="history -a"
# append to the history file, don't overwrite it
shopt -s histappend
# update the values of LINES and COLUMNS.
shopt -s checkwinsize
# reedit a history substitution line if it failed
shopt -s histreedit
# edit a recalled history line before executing
shopt -s histverify

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
*-256color)
    alias ssh='TERM=${TERM%-256color} ssh'
    ;;
*)
    POTENTIAL_TERM=${TERM}-256color
    POTENTIAL_TERMINFO=${TERM:0:1}/$POTENTIAL_TERM

    # better to check $(toe -a | awk '{print $1}') maybe?
    BOX_TERMINFO_DIR=/usr/share/terminfo
    [[ -f $BOX_TERMINFO_DIR/$POTENTIAL_TERMINFO ]] && \
        export TERM=$POTENTIAL_TERM

    HOME_TERMINFO_DIR=$HOME/.terminfo
    [[ -f $HOME_TERMINFO_DIR/$POTENTIAL_TERMINFO ]] && \
        export TERM=$POTENTIAL_TERM
    ;;
esac


# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ ➜ \1/'
}

if [ "$color_prompt" = yes ]; then
    # gray icon, blue directory, green git, yellow dollar
    PS1="\[\e[5;33m\]•\[\e[m\] \[\e[1;34m\]\W\[\e[m\]\[\e[1;32m\]\$(parse_git_branch)\[\e[m\] \[\e[0;33;40m\]\\$\[\e[m\] \[$(tput sgr0)\]"
else
    PS1="• \W\$(parse_git_branch) \\$\[$(tput sgr0)\] "
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/ibreschi/google-cloud-sdk/path.bash.inc' ]; then . '/home/ibreschi/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/ibreschi/google-cloud-sdk/completion.bash.inc' ]; then . '/home/ibreschi/google-cloud-sdk/completion.bash.inc'; fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion >/dev/null 2>&1
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


#Virtual Env stuff
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3.8
export WORKON_HOME=~/.environments

# load virtualenvwrapper for python (after custom PATHs)
venvwrap="virtualenvwrapper.sh"
/usr/bin/which -a $venvwrap >/dev/null 2>&1
if [ $? -eq 0 ]; then
    venvwrap=`/usr/bin/which $venvwrap`
    source $venvwrap
fi


export PYTHONSTARTUP=~/.pythonrc
export EDITOR='vim'
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Deepomatic related stuff
export MAKEFLAGS="-j $(($(nproc) / 4))"
export DMAKE_UID=0
export MINIKUBE_HOME=$HOME/.minikube
export DEEPOMATIC_CONFIG_DIR=/home/ibreschi/Deepomatic/git/env
export KUBECONFIG=$HOME/.kube/config:$DEEPOMATIC_CONFIG_DIR/kubernetes/config:$MINIKUBE_HOME/kubeconfig
export VULCAN_MINIKUBE_CONTEXT=minikube
export DOCKER_BUILDKIT=1
export DMAKE_GITHUB_OWNER=deepomatic
export GPU_MEMORY_FRACTION=0.15
source /home/ibreschi/.dmake/config.sh

export VAULT_ADDR=https://vault.stag.k8s.deepomatic.com
source <(kubectl completion bash)
. "$HOME/.cargo/env"
source /home/ibreschi/git/alacritty/extra/completions/alacritty.bash

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

