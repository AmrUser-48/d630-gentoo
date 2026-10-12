# Reinforce the interactive defaults from EMERGE_DEFAULT_OPTS in make.conf.
# Non-interactive scripts do not read this interactive-shell alias.
if [[ $- == *i* ]]; then
    alias emerge='emerge --ask --verbose'
fi
