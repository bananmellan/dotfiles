if [ $TERMUX_VERSION ]; then source ~/.profile; fi

if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Only trigger if:
# - 'fish' is not the parent process of this shell
# - We did not call: bash -c '...'
# - The fish binary exists and is executable
if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && \
          -z ${BASH_EXECUTION_STRING} && -x "$(which fish)" ]]; then
    shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=''
    exec fish $LOGIN_OPTION
elif [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi
