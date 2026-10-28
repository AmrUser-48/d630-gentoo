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
