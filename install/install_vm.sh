#!/bin/bash

export SHELL=/bin/bash

version="1.0.1"

if [ $# -lt 2 ]; then
    echo "Invalid parameter. Use: $0 \"<user name>\" \"<email name>\""
    exit 1
fi

userName=$1
emailName=$2

doDisplay() {
    local color=$1

    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"

    #read -p "Press enter to continue"
}

installApplication() {

    local package=$1
    doDisplay 6 Install application .... package: $package

    sudo NEEDRESTART_MODE=a apt-get install $package --yes
    # sudo DEBIAN_FRONTEND=noninteractive apt-get -y install $package -y

    doDisplay 5 "$(apt-cache show $package | grep 'Package\|Version')"
}

makeAlias() {
    cat <<EOF >~/.bash_aliases

parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[01;31m\]\$(parse_git_branch)\[\033[00m\]$ '

function _colorman() {
  env \
    LESS_TERMCAP_mb=$'\e[1;35m' \
    LESS_TERMCAP_md=$'\e[1;34m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[7;40m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[1;33m' \
    LESS_TERMCAP_mr=$(tput rev) \
    LESS_TERMCAP_mh=$(tput dim) \
    LESS_TERMCAP_ZN=$(tput ssubm) \
    LESS_TERMCAP_ZV=$(tput rsubm) \
    LESS_TERMCAP_ZO=$(tput ssupm) \
    LESS_TERMCAP_ZW=$(tput rsupm) \
    GROFF_NO_SGR=1 \
      "$@"
}
alias man="LANG=C _colorman man"
function perldoc() { command perldoc -n less "$@" |man -l -; }

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

EOF
}

installEnv() {

    doDisplay 6 Install environment ....
    makeAlias

    sudo setxkbmap -model abnt2 -layout br
    sudo timedatectl set-timezone America/Sao_Paulo
    gsettings set org.gnome.desktop.session idle-delay 900
    gsettings set org.gnome.desktop.interface gtk-theme "CoolestThemeOnEarth"

    sudo apt -y update
    sudo apt -y upgrade
}
installPython() {
    # https://cloudbytes.dev/snippets/upgrade-python-to-latest-version-on-ubuntu-linux

    doDisplay 6 Install python3 ....
    sudo add-apt-repository ppa:deadsnakes/ppa
    sudo apt update

    if [ ! -f /usr/bin/python3 ]; then

        sudo apt-get -y install python3.12
        sudo apt-get -y install python3-pip
        sudo apt-get -y install python3.12-venv
        sudo apt-get -y install python3.12-distutils

        python3.12 -m venv env
        sudo rm /usr/bin/python
        sudo ln -s /usr/bin/python3.12 /usr/bin/python
        #source env/bin/activate
    fi

}

installVisualCode() {

    doDisplay 6 Install Visual code ....

    sudo apt-get -y install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg

    sudo apt -y autoremove
    sudo apt -y install apt-transport-https
    sudo apt -y update
    sudo apt -y install code # or code-insiders

    cp /usr/share/applications/code.desktop ~/Desktop

    code --install-extension ms-vscode.cpptools
    code --install-extension jbenden.c-cpp-flylint
    code --install-extension ms-vscode.cpptools-extension-pack
    code --install-extension ms-vscode.cpptools-themes
    code --install-extension matepek.vscode-catch2-test-adapter
    code --install-extension xaver.clang-format

    code --install-extension twxs.cmake
    code --install-extension ms-vscode.cmake-tools

    code --install-extension ms-azuretools.vscode-docker
    code --install-extension GitHub.copilot
    code --install-extension GitHub.copilot-chat
    code --install-extension GitHub.github-vscode-theme
    code --install-extension ms-vscode.powershell
    code --install-extension eamodio.gitlens
    code --install-extension foxundermoon.shell-format
}

installChrome() {

    doDisplay 6 Install chrome ....

    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt -y install ./google-chrome-stable_current_amd64.deb
    sudo dpkg -i google-chrome-stable_current_amd64.deb

    sudo apt -y autoremove
    sudo apt-get -y install -f

    rm -f google-chrome-stable_current_amd64.deb
    cp /usr/share/applications/google-chrome.desktop ~/Destop
}

createSslKeyOnGit() {
    doDisplay 2 "**********************************************************************"
    doDisplay 2 "* Instructions                                                       *"
    doDisplay 2 "*                                                                    *"
    doDisplay 2 "* The script will launch chrome to create new ssh key to github      *"
    doDisplay 2 "*      - Login on github                                             *"
    doDisplay 2 "*      - Use Ctrl-C to copy key value in Key github field            *"
    doDisplay 2 "*      - Close the browser to return                                 *"
    doDisplay 2 "*                                                                    *"
    doDisplay 2 "**********************************************************************"

    read -p "Press enter to continue"
    cat ~/.ssh/id_ed25519.pub | xsel -ib
    google-chrome --disable-gpu --disable-software-rasterizer --new-window https://github.azc.ext.hp.com/settings/ssh/new

    doDisplay 6 "Key creation ended successfully?"
    select ret in "Yes" "No" "Exit"; do
        case $ret in
        Yes)
            return
            ;;
        No)
            createSslKeyOnGit
            break
            ;;
        Exit)
            exit 1
            ;;
        esac
    done
}

configGitHub() {

    doDisplay 6 Install Github configuration ....
    local name=$1
    local email=$2

    git config --global user.name "$name"
    git config --global user.email "$email"

    doDisplay 6 "Do you wish install ssh key on github?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            ssh-keygen -t ed25519 -C $email
            eval "$(ssh-agent -s)"
            cat ~/.ssh/id_ed25519.pub
            createSslKeyOnGit
            break
            ;;
        No)
            return
            ;;
        esac
    done

}

installDocker() {

    doDisplay 6 Install Docker ....

    curl -fsSL https://get.docker.com -o install-docker.sh

    sh install-docker.sh --dry-run
    sudo sh install-docker.sh

    rm install-docker.sh
    local countGrp=$(cat /etc/group | grep -c docker)
    if [ $countGrp -eq 0 ]; then
        sudo groupadd docker
    fi

    sudo usermod -aG docker $USER

    #sudo newgrp docker

}

restart() {
    doDisplay 6 "To apply changes, the system must be restarted"
    doDisplay 6 "Do you wish restart the system?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            sudo reboot
            break
            ;;
        No)
            return
            ;;
        esac
    done
}

sudo apt-get -y remove needrestart

installEnv
installPython

installApplication build-essential
installApplication gdb

installApplication git
installApplication curl
installApplication xsel

installApplication wget
installApplication xdg-utils
installApplication gnome-tweaks
installApplication jq

doDisplay 6 Install notepad-plus-plus ....
sudo snap install notepad-plus-plus
cp /var/lib/snapd/desktop/applications/notepad-plus-plus_notepad-plus-plus.desktop ~/Desktop

installVisualCode
installChrome
installApplication firefox
cp /usr/share/applications/firefox.desktop ~/Desktop

installDocker
sudo apt-get -y install needrestart

configGitHub "$userName" "$emailName"

doDisplay 6 "Enter the workspace directory base:[~/development/hp]"
read $baseDirectory
if [ -z "$baseDirectory" ]; then
    baseDirectory=~/development/hp
fi
mkdir -p $baseDirectory

cd $baseDirectory

git clone git@github.azc.ext.hp.com:Anyware-Infrastructure/Environment-Setup.git

doDisplay 6 "You have oportunity to clone work repository"
doDisplay 6 "Enter repository to clone or enter to exit"
read repository

if [ ! -z "$repository" ]; then
    git clone git@github.azc.ext.hp.com:Anyware-Software/$repository.git
fi

restart
