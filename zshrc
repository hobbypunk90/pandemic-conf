PANDEMIC_VERSION=0
# https://github.com/hobbypunk90/pandemic-conf/blob/main/zshrc

function update {
  if [ "$PANDEMIC_VERSION" = "" ] || ping -W1 -c1 github.com &>/dev/null; then
    tmp_file=$(mktemp -t pandemic_zsh.XXXXXX)
    load_pandemic $tmp_file
    if check_pandemic $tmp_file; then
      if update_pandemic $tmp_file; then
        echo "Please restart..."
      fi
    fi
    rm -f $tmp_file
  fi
}

function silent_update {
  setopt local_options no_notify no_monitor
  update &
}

function load_pandemic {
  tmp_file=$1
  curl -i "https://api.github.com/repos/hobbypunk90/pandemic-conf/contents/zshrc" 2>/dev/null >$tmp_file
}

function check_pandemic {
  tmp_file=$1
  date=$(cat $tmp_file | sed -n 's/[Ll]ast-[Mm]odified: \(.*\)/\1/p')
  if [ "$?" = "0" ]; then
    if where gdate &>/dev/null; then
      version=$(gdate --date="$date" +"%s")
    else
      version=$(date --date="$date" +"%s")
    fi
  fi

  if [[ "$version" != "" && "$PANDEMIC_VERSION" = "" || $PANDEMIC_VERSION -lt $version ]]; then
    echo "New evolution stage detected."
    NEW_PENDAMIC_VERSION=$version
    true
  else
    false
  fi
}

function update_pandemic {
  tmp_file=$1
  echo "Evolving..."
  content="$(cat $tmp_file | sed -n 's/"content": "\(.*\)",/\1/p' | tr -d ' ')"
  echo -e "$content" | base64 -d > $tmp_file
  if ! grep "^PANDEMIC_VERSION=" $tmp_file &>/dev/null; then
    false
  else
    sed -i".bak" "1 s/PANDEMIC_VERSION=.*/PANDEMIC_VERSION=$version/" $tmp_file
    rm "${tmp_file}.bak"
    # follow symbolic link 😉
    echo -n "Mutate... "
    cp $tmp_file /tmp/zshrc.$USER
    if source /tmp/zshrc.$USER; then
      cat /tmp/zshrc.$USER > ~/.zshrc
      echo "accepted"
    else
      echo "discarded"
    fi
    rm /tmp/zshrc.$USER
    true
  fi
}

function load_zshrc {
  EDITOR=nano

  HISTFILE=~/.zsh_history
  HISTSIZE=10000
  SAVEHIST=10000
  bindkey -e

  function install_antigen {
    echo "Install Antigen"
    if cat /etc/os-release | grep -P "ID(_LIKE)?=arch"; then
      echo "Arch based system detected, try to install antigen from aur..."
      if where pikaur &> /dev/null; then
        pikaur -S antigen
      elif where yay &> /dev/null; then
        yay -S antigen
      fi
    elif where opkg &> /dev/null; then
      echo "OPKG based system detected, install curl and git with opkg, then install antigen with fallback..."
      opkg install ca-certificates
      opkg install ca-bundle
      opkg install curl
      opkg install git
      install_antigen_fallback
    elif [ -f /etc/debian_version ]; then
      echo "Debian based system detected, install dependencies, then install antigen with fallback..."
      if [ "$USER" = "root" ]; then
        apt install -y ca-certificates curl git
      else
        sudo apt install -y ca-certificates curl git
      fi
      install_antigen_fallback
    elif where sw_vers &> /dev/null; then
      echo "Mac OS X detected, install antigen with Brew..."
      brew install antigen
    else
      echo "Do you want to install fallback antigen(download it to ~/.antigen/antigen.zsh)? [y/N]"
      read yn
      case $yn in
        [Yy]* ) install_antigen_fallback;;
  	* ) echo "Abort...";;
      esac
    fi
  }

  function install_antigen_fallback {
    mkdir -p ~/.antigen
    curl -L git.io/antigen > ~/.antigen/antigen.zsh
  }

  if [ ! -f /usr/share/zsh/share/antigen.zsh ] && [ ! -f /usr/local/share/antigen/antigen.zsh ] && [ ! -f ~/.antigen/antigen.zsh ]; then
    install_antigen
    if [ ! -f /usr/share/zsh/share/antigen.zsh ] && [ ! -f /usr/local/share/antigen/antigen.zsh ] && [ ! -f ~/.antigen/antigen.zsh ]; then
      exit 1
    fi
  fi

  if [ -f /usr/share/zsh/share/antigen.zsh ]; then
    source /usr/share/zsh/share/antigen.zsh
  elif [ -f /usr/local/share/antigen/antigen.zsh ]; then
    source /usr/local/share/antigen/antigen.zsh
  elif [ -f ~/.antigen/antigen.zsh ]; then
    source ~/.antigen/antigen.zsh
  fi

  antigen use oh-my-zsh

  if [ -f /usr/bin/mise ]; then
    eval "$(mise activate zsh --shims)" # this sets up interactive sessions
  fi

  antigen bundle git
  antigen bundle git-extra
  if $(where tput > /dev/null); then
    antigen bundle mvn
  fi
  antigen bundle pip
  antigen bundle rails
  antigen bundle systemd
  antigen bundle docker
  antigen bundle macunha1/zsh-terraform

  antigen bundle zsh-users/zsh-completions
  antigen bundle zsh-users/zsh-autosuggestions
  antigen bundle zsh-users/zsh-syntax-highlighting

  antigen apply

  autoload -Uz compinit
  compinit

  autoload -Uz vcs_info
  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' unstagedstr "%F{red} ●%f"
  zstyle ':vcs_info:*' formats "(%F{blue}%s%f:%F{yellow}%b%f)"
  zstyle ':vcs_info:git*' formats "(%F{cyan}%s%f:%F{yellow}%b%f%u)"
  zstyle ':vcs_info:*' check-for-changes true

  zstyle ':completion:*' accept-exact '*(N)'
  zstyle ':completion:*' use-cache on
  zstyle ':completion:*' cache-path ~/.zsh/cache

  precmd() {
    vcs_info &>/dev/null
  }

  autoload -Uz promptinit
  promptinit
  prompt redhat

  setopt PROMPT_SUBST
  setopt extended_glob

  function battery {
    batid=$1
    cap=$(upower -i $batid | grep -Po "(?<=percentage:).*" | grep -Po "\d+" )
    adapter=$(upower -i $batid | grep -Po "(?<=state:).*" | grep -Po "[A-Za-z\-]+")
    color="red"
    if [[ $cap -gt 15 ]] && [[ $cap -lt 50 ]]; then color="yellow"; fi
    if [[ $cap -ge 50 ]]; then color="green"; fi
    rprompt="%F{$color}$cap"
    if [ "$adapter" = "discharging" ]; then
      rprompt="$rprompt%%%f";
    else
      rprompt="$rprompt%f%F{yellow}↯%f";
    fi
    echo $rprompt
  }

  function temp {
    t=$(cat /sys/class/thermal/thermal_zone0/temp)
    full_temp="$(( t / 1000 )).$((t % 1000 / 100))'C"
    temp=$( echo $t | cut -c1,2 )
    color="green"
    if [[ $temp -gt 60 ]] && [[ $temp -lt 80 ]]; then color="yellow"; fi
    if [[ $temp -ge 80 ]]; then color="red"; fi
    echo "%F{$color}$full_temp%f"
  }

  function extension {
    if where upower &>/dev/null && [ "$(upower -e | grep -m1 "BAT")" != "" ]; then
      battery $(upower -e | grep -m1 "BAT")
    elif [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
      temp
    fi
  }

  function version_control() {
    echo ${vcs_info_msg_0_}
  }

  function last_exit_code() {
    last_exit_code=$?
    if [[ $last_exit_code -ne 0 ]]; then
      echo "%F{red}$last_exit_code%f "
    fi
  }

  if where glances &>/dev/null; then
    alias glances='glances'
    alias top='glances'
  fi
  alias vi='vim'

  # create a zkbd compatible hash;
  # to add other keys to this hash, see: man 5 terminfo
  typeset -g -A key

  key[Home]="${terminfo[khome]}"
  key[End]="${terminfo[kend]}"
  key[Insert]="${terminfo[kich1]}"
  key[Backspace]="${terminfo[kbs]}"
  key[Delete]="${terminfo[kdch1]}"
  key[Up]="${terminfo[kcuu1]}"
  key[Down]="${terminfo[kcud1]}"
  key[Left]="${terminfo[kcub1]}"
  key[Right]="${terminfo[kcuf1]}"
  key[PageUp]="${terminfo[kpp]}"
  key[PageDown]="${terminfo[knp]}"
  key[Shift-Tab]="${terminfo[kcbt]}"

  # setup key accordingly
  [[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"       beginning-of-line
  [[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"        end-of-line
  [[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"     overwrite-mode
  [[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}"  backward-delete-char
  [[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"     delete-char
  [[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         up-line-or-beginning-search
  [[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       down-line-or-history
  [[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"       backward-char
  [[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"      forward-char
  [[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"     beginning-of-buffer-or-history
  [[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"   end-of-buffer-or-history
  [[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}"  reverse-menu-complete

  # Finally, make sure the terminal is in application mode, when zle is
  # active. Only then are the values from $terminfo valid.
  if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    autoload -Uz add-zle-hook-widget
    function zle_application_mode_start { echoti smkx }
    function zle_application_mode_stop { echoti rmkx }
    add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
    add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
  fi

  PROMPT="[%F{red}%n%f@%F{blue}%m%f:%F{green}%1~%f]%# "
  RPROMPT='$(last_exit_code)$(version_control)$(extension)'

  alias myip="curl https://www.monip.org -s | grep -Po --color=never \"(?<=IP : )[\d\.]+\""

  if [ "$XDG_SESSION_DESKTOP" = "gnome" ]; then
    alias afk="dbus-send --type=method_call --dest=org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock"
  elif [ "$XDG_SESSION_DESKTOP" = "KDE" ]; then
    alias afk="loginctl lock-session"
  fi

  function rsync {
    if [ -f ./.rsyncignore ]; then
      /usr/bin/rsync --progress --partial -hr --exclude-from=./.rsyncignore $@
    else
      /usr/bin/rsync --progress --partial -hr $@
    fi
  }

  if [ -d $HOME/.local/bin ]; then
    PATH=$HOME/.local/bin:$PATH
  fi

  if [ -d $HOME/.cargo/bin ]; then
    PATH=$HOME/.cargo/bin:$PATH
  fi

  alias dd="dd status=progress"
  if where terraform &>/dev/null; then
    alias tfsearch='tfp -out=/tmp/tfplan && tfs -json /tmp/tfplan | jq'
  fi

  if where kubectl &>/dev/null && [ -d "${HOME}/.kube" ]; then
    if [ -f "${HOME}/.kube/config" ]; then
      export KUBECONFIG="${HOME}/.kube/config"
    fi

    if ls "${HOME}/.kube/" | grep ".kube" &>/dev/null; then
      for file in ${HOME}/.kube/*.kube; do 
        if [ "" = "${KUBECONFIG}" ]; then
          export KUBECONFIG="${file}"
        else
          export KUBECONFIG="${file}:${KUBECONFIG}"
        fi
      done
    fi

    if kubectl krew &>/dev/null; then
      export PATH="${PATH}:${HOME}/.krew/bin"
      eval "$(kubectl krew completion zsh)"
    fi

    if kubectl hns &>/dev/null; then
      eval "$(kubectl hns completion zsh)"
    fi

  fi

  if where codium &>/dev/null; then
    alias code="codium"
  fi
  
  if where gpaste-client &>/dev/null; then
    alias copy="gpaste-client"
    alias paste="gpaste-client --use-index get 0"
  fi
}

silent_update

load_zshrc

# load personal extra stuff
# make custom changes only to the .zshrcx file.
if [ -f ~/.zshrcx ]; then
  source ~/.zshrcx
fi

if [ -f ~/.fzf.zsh ]; then
  source ~/.fzf.zsh
fi
