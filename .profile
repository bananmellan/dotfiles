export HEM=$HOME/.hem

export PATH=$HEM/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/bin:$PATH
export PATH=$PATH:/opt/local/bin
export PATH=$PATH:$HOME/.cargo/bin
export PATH=/home/linuxbrew/.linuxbrew/bin:$PATH
export PATH=/home/linuxbrew/.linuxbrew/sbin:$PATH
export PATH=$HOME/.venv/bin:$PATH

export XDG_CONFIG_HOME=$HOME/.config
export ORG_DIR=$HEM-.org
export GOPATH=$HOME/.go/bin
export PASSWORD_STORE_DIR=$HEM.crypt/päss
export GDK_BACKEND=wayland
export ENCRYPTED_CREDENTIALS_DIRECTORY=$HOME/.secrets
export MANPATH=$MANPATH:$HOME/.local/share/man
export PIPEWIRE_LATENCY=128/44100

# This file is explicitly sourced in .bashrc if launched in Termux, must prevent
# recursive loop
[ -f ~/.bashrc ] && [ -z "$TERMUX_VERSION" ] && . ~/.bashrc
