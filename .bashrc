# Only trigger if:
# - Shell is interactive ($- == *i*)
# - 'fish' is not the parent process of this shell
# - We did not call: bash -c '...'
# - The fish binary exists and is executable
if [[ $- == *i* ]] && [ $TERM != dumb ] && \
       [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && \
              -z ${BASH_EXECUTION_STRING} && -x "$(which fish)" ]] && \
   [[ -n $PTYXIS_VERSION || -n $SSH_CONNECTION || $TERM_PROGRAM=kgx ]]; then
    shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=''
    exec fish $LOGIN_OPTION
elif [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi
