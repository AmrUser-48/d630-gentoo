case $- in
  *i*) ;;
  *) return ;;
esac

PS1='\[\e[1;32m\]\u@d630-tiny\[\e[0m\]:\w\$ '
export EDITOR=vi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'

lfcd() {
  local last_dir
  last_dir=$(mktemp) || return
  lf -last-dir-path="$last_dir" "$@"
  if [[ -s "$last_dir" ]]; then
    local directory
    IFS= read -r directory < "$last_dir"
    rm -f -- "$last_dir"
    if [[ -d "$directory" && "$directory" != "$PWD" ]]; then
      cd -- "$directory"
    fi
  else
    rm -f -- "$last_dir"
  fi
}

bind '"\C-o":"\C-u lfcd\C-m"'
