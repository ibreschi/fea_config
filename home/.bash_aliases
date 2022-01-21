# Coloring
# requires pip install --user alacritty-colorscheme
LIGHT_COLOR='base16-tomorrow-256.yml'
DARK_COLOR='base16-humanoid-dark-256.yml'

alias day="alacritty-colorscheme -V apply $LIGHT_COLOR"
alias night="alacritty-colorscheme -V apply $DARK_COLOR"
alias toggle="alacritty-colorscheme -V toggle $LIGHT_COLOR $DARK_COLOR"

# Various Stuff
alias gr='ag '
alias ff='find . -iname '

# Git Stuff
alias g='git'
alias Gc='g checkout'
alias Gcm='g checkout master'
alias Gd='g diff'
alias Gdel='g branch -D '
alias Gnb='g checkout -b'
alias Gp='g pull'
alias Grc='g rebase --continue'
alias Gri='g rebase -i'
alias Gs='g status'
alias Gt='g tree'
alias Gprune='g remote update origin --prune'
source /usr/share/bash-completion/completions/git

# Docker Stuff
alias d='docker'
alias dc='docker-compose'
# Kubernetes Stuff
alias k='kubectl'
alias kx="kubectl ctx"
alias kn="kubectl ns"

# aliases to load completion for
for a in d dc k; do
    complete -F _complete_alias "${a}"
done
complete -F _complete_alias kx
complete -F _complete_alias kn
## KEEP AT THE END OF THE FILE
source $HOME/git/complete-alias/complete_alias

# Deepo stuff
alias jenkins_master='gcloud compute ssh jenkins --zone europe-west4-b'

# VPN
function deepo_vpn {
  sudo openfortivpn -c ~/.vpn_conf --use-syslog
}

function deepo_acacia {
  if ! pgrep openfortivpn; then
      echo "Forti off"
      deepo_vpn &
      sleep 7
  fi
  echo "Forti on"
  ssh acacia
}
