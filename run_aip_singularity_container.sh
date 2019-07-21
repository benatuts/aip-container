#!/usr/bin/env bash

# First parameter to this script is the container app name, defaulting to term
APP=${1:-term}

# Check and ensure correct parameter $1 passed in
case $APP in
  term )
    echo "Starting GNOME Terminal";;
  fullterm )
    echo "Starting full terminal";;
  vscode )
    echo "Starting VS Code";;
  * )
    echo "
    Use $0 to manually start the container:
    # Start a gnome-terminal
      $ run_aip_singularity_container.sh term

    # Start visual studio code
      $ run_aip_singularity_container.sh vscode

    # Start a gnome-terminal-server and gnome-terminal
      $ run_aip_singularity_container.sh fullterm
    "
    exit 1
    ;;
esac

# Singularity image to use
SIF=aip-container_latest.sif

if [ ! -f ${SIF} ]; then
  echo "Can't locate ${SIF}.  Please check your path and image location."
  exit 1
fi

# Setup defaults to use if .config/aip_container is not present
if [ -d "/images/tmp" ]
then
    # We're on a UTS computer, there is lots more storage in /images/tmp
    BASE_PATH="/images/tmp"
    HOST_PATH="/images/tmp/$USER/aip"
    SYMLINK=(".gitconfig" ".ssh")
else
    # Default to using /tmp
    BASE_PATH="/tmp"
    HOST_PATH="/tmp/$USER/aip"
    SYMLINK=(".gitconfig" ".ssh")
fi

# Read the config file in ~/.config/aip_container
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/aip_container"
if [ -f "$CONFIG_FILE" ]
then
    source "$CONFIG_FILE"
fi

# Only create a workspace if BASE_PATH exists (i.e., is mounted)
if [ -d "$BASE_PATH" ]
then
    # Ensure the HOST_PATH exists
    export SINGULARITYENV_HOST_PATH="$HOST_PATH"
    (umask 077 && mkdir -p "$SINGULARITYENV_HOST_PATH")

    # Create symlinks for important files
    for f in "${SYMLINK[@]}"
    do
        if [ -e "$HOME/$f" ] && [ ! -e "$HOST_PATH/$f" ] && [ ! -L "$HOST_PATH/$f" ]
        then
            ln -s "/host$HOME/$f" "$HOST_PATH/$f"
        fi
    done

    # Create a default .bashrc, if none exists
    if [ ! -e "$HOST_PATH/.bashrc" ] && [ ! -L "$HOST_PATH/.bashrc" ]
    then

        cat > "$HOST_PATH/.bashrc" <<EOM
echo
echo "You are using a container."
echo "Your home is bound to \$(tput bold)\$HOST_PATH\$(tput sgr0) on the host."
if [[ "\$HOST_PATH" == *"/tmp/"* ]]; then
    echo "Ensure your changes are saved or committed before leaving."
fi
echo
export PS1="[container \\W]\\\\\$ "
EOM

    fi

    # This is needed for compatibility with some distributions, because we're remapping home
    XAUTH="$SINGULARITYENV_HOST_PATH/.Xauthority"
    touch "$XAUTH"
    xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f "$XAUTH" nmerge -

    # Launch the container
    singularity run --app $APP -B $HOME:/host$HOME -H "$SINGULARITYENV_HOST_PATH":$HOME -B /run --pwd $HOME $SIF
else
    echo "BASE_PATH ($BASE_PATH) does not exist, will not create HOST_PATH."
    echo "Container start failed"
    
    # Try to show a GUI dialog
    (zenity --error --no-wrap --text="Container base path does not exist:\n$BASE_PATH\n\nPlease check any required disk drives (or USB memory sticks) are mounted.\n\nYour base path is configured in:\n$CONFIG_FILE" ||  \
     python2 -c "import Tkinter;r=Tkinter.Tk();r.withdraw();import sys;import tkMessageBox;tkMessageBox.showerror('Cannot start container', 'Container base path does not exist:\n' + sys.argv[1] + '\n\nPlease check any required disk drives (or USB memory sticks) are mounted.\n\nYour base path is configured in:\n' + sys.argv[2]);" "$BASE_PATH" "$CONFIG_FILE")
    
    exit 1
fi
