PANDEMIC_VERSION=0

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
  	if uname -r | grep ARCH &> /dev/null; then
  		echo "Arch based system detected, try to install antigen from aur..."
  		pikaur -S antigen-git
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

  antigen bundle git
  antigen bundle git-extra
  if $(where tput > /dev/null); then
  	antigen bundle mvn
  fi
  antigen bundle pip
  antigen bundle rails
  antigen bundle systemd
  antigen bundle docker

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
    if where upower &>/dev/null && [ "$(upower -e | grep -m1 "battery")" != "" ]; then
      battery $(upower -e | grep -m1 "battery")
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

  #if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    bindkey "\e[1~" beginning-of-line
    bindkey "\e[4~" end-of-line
    bindkey "\e[5~" beginning-of-history
    bindkey "\e[6~" end-of-history
    bindkey "\e[7~" beginning-of-line
    bindkey "\e[3~" delete-char
    bindkey "\e[2~" quoted-insert
    bindkey "\e[5C" forward-word
    bindkey "\e[5D" backward-word
    bindkey "\e\e[C" forward-word
    bindkey "\e\e[D" backward-word
    bindkey "\e[1;5C" forward-word
    bindkey "\e[1;5D" backward-word
    bindkey "\e[8~" end-of-line
    bindkey "\eOH" beginning-of-line
    bindkey "\eOF" end-of-line
    bindkey "\e[H" beginning-of-line
    bindkey "\e[F" end-of-line
  #fi

  PROMPT="[%F{red}%n%f@%F{blue}%m%f:%F{green}%1~%f]%# "
  RPROMPT='$(last_exit_code)$(version_control)$(extension)%'

  alias myip="curl https://www.monip.org -s | grep -Po --color=never \"(?<=IP : )[\d\.]+\""
  if where filebot &>/dev/null; then
  	alias filebot_movie="filebot -no-xattr -non-strict -rename --lang ger --db TheMovieDB --format \"{n.colon(' - ')} ({y}){' CD'+pi}\""
  	alias filebot_serie="filebot -no-xattr -non-strict -rename --order airdate --lang ger --db TheTVDB --format \"./{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}\""
  	alias filebot_season="filebot -no-xattr -non-strict -rename --order airdate --lang ger --db TheTVDB --format \"./Season {s.pad(2)}/{n} - {s00e00} - {t}\""
  	alias filebot_episodes="filebot -no-xattr -non-strict -rename --order airdate --lang ger --db TheTVDB --format \"./{n} - {s00e00} - {t}\""
  fi

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

  alias dd="dd status=progress"

  # Load {rb|py|nod|j}env automatically if existing
  if where rbenv &>/dev/null; then
  	eval "$(rbenv init -)"
  fi

  if where pyenv &>/dev/null; then
  	eval "$(pyenv init -)"
  	eval "$(pyenv virtualenv-init - 2> /dev/null)"
  fi

  if where nodenv &>/dev/null; then
  	eval "$(nodenv init -)"
  fi

  if where jenv &>/dev/null; then
    eval "$(jenv init -)"
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
