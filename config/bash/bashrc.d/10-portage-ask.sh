# Prompt before applying changes when emerge is run from an interactive Bash shell.
# Automation scripts use explicit --ask=n or their own TTY-aware prompt policy.
if [[ $- == *i* ]]; then
    alias emerge='emerge --ask'
fi
