#!/bin/bash
set -euo pipefail

readonly USAGE="Usage: provision.sh [-l | -c <command_name>]"

main() {
  while getopts ":lch" opt; do
    case ${opt} in
      l)
        declare -F | awk '{ print $3 }' | grep -vE "(main|go_get|git_clone)"
        exit 0
        ;;
      c)
        shift $((OPTIND - 1))
        for command in $@; do
          $command
        done
        exit 0
        ;;
      h)
        echo $USAGE
        exit 0
        ;;
      \?)
        echo "Invalid option: $OPTARG" 1>&2
        echo $USAGE
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  echo ">>> Installing everything..."
  mkdir_home_user_bin
  install_ibmcloud_cli
  setup_helm_client
  install_gotools
  install_ohmyzsh
  install_vim_plug
  install_nvim_extensions
  install_rbenv
  install_cred_alert
  configure_dotfiles
  clone_git_repos
  install_git_hooks
  install_vim_plugins
  install_misc_tools
  install_pure_zsh_theme
  install_tmux_plugin_manager
  install_zsh_autosuggestions
  init_pass_store
  switch_to_zsh
}

mkdir_home_user_bin() {
  mkdir -p $HOME/bin
}

install_cred_alert() {
  os_name=$(uname | awk '{print tolower($1)}')
  curl -o cred-alert-cli \
    https://s3.amazonaws.com/cred-alert/cli/current-release/cred-alert-cli_${os_name}
  chmod 755 cred-alert-cli
  mv cred-alert-cli "$HOME/bin/"
}

install_ibmcloud_cli() {
  if [[ ! $(command -v ibmcloud) ]]; then
    echo ">>> Installing the IBM Cloud CLI"
    curl -sL https://ibm.biz/idt-installer | bash
    ibmcloud plugin install kubernetes-service -f
  fi
}

setup_helm_client() {
  echo ">>> Setting up the Helm client"
  helm init --client-only
}

install_gotools() {
  echo ">>> Installing golangci-lint"
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "$HOME/go/bin/" v1.32.1

  echo ">>> Installing gopls"
  GO111MODULE=on go_get golang.org/x/tools/gopls@latest

  echo ">>> Installing fillstruct"
  go_get -u github.com/davidrjenni/reftools/cmd/fillstruct

  echo ">>> Installing gomodifytags"
  go_get -u github.com/fatih/gomodifytags

  echo ">>> Installing keyify"
  go_get -u honnef.co/go/tools/cmd/keyify

  echo ">>> Installing goimports"
  go_get -u golang.org/x/tools/cmd/goimports

  echo ">>> Installing gci"
  go_get -u github.com/daixiang0/gci
}

install_ohmyzsh() {
  echo ">>> Installing Oh My Zsh"
  [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  # Delete default .zshrc to avoid stow conflicts
  rm -f "$HOME/.zshrc"
}

install_tmux_plugin_manager() {
  echo ">>> Installing TPM"
  git_clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
}

install_zsh_autosuggestions() {
  echo ">>> Installing zsh-autosuggestions"
  git_clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
}

install_vim_plug() {
  echo ">>> Installing vim-plug"
  curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

install_nvim_extensions() {
  echo ">>> Installing the NeoVim extensions"
  sudo npm install -g neovim
  pip3 install --upgrade pip
  pip3 install --upgrade neovim
  gem install neovim --user-install
}

install_rbenv() {
  echo ">>> Installing Ruby with rbenv"

  local rbenv_root
  rbenv_root="$HOME/.rbenv"

  if [[ -d "$rbenv_root" ]]; then
    return
  fi

  git_clone https://github.com/rbenv/rbenv.git "$rbenv_root"

  mkdir -p "$rbenv_root/plugins"
  git_clone https://github.com/rbenv/ruby-build.git "$rbenv_root/plugins/ruby-build"

  PATH="$rbenv_root/bin:$PATH" rbenv install 2.5.5
}

clone_git_repos() {
  echo ">>> Cloning our Git repositories"

  mkdir -p "$HOME/workspace"
  pushd "$HOME/workspace"
  {
    git_clone "git@github.com:cloudfoundry-incubator/eirini-ci.git"
    git_clone "git@github.com:cloudfoundry-incubator/eirini-release.git" "" develop
    git_clone "git@github.com:cloudfoundry-incubator/eirini-staging.git"
    git_clone "git@github.com:cloudfoundry-incubator/eirini.git"
    git_clone "git@github.com:cloudfoundry/capi-k8s-release.git"
    git_clone "git@github.com:cloudfoundry/capi-release.git"
    git_clone "git@github.com:cloudfoundry/cf-for-k8s.git"
    git_clone "git@github.com:cloudfoundry/eirini-private-config.git"
    git_clone "git@github.com:eirini-forks/eirini-station.git"
  }
  popd
}

git_clone() {
  local url path name branch
  url=$1
  path=${2:-""}
  branch=${3:-""}

  if [ -z "$path" ]; then
    name=$(echo "$url" | sed 's/\.git//g' | cut -d / -f 2)
    path="$HOME/workspace/$name"
  fi

  if [ -d "$path" ]; then
    echo "Repository $path already exists. Skipping git clone..."
    return
  fi

  git clone "$url" "$path"

  if [ -f "$path/.gitmodules" ]; then
    git -C "$path" submodule update --init --recursive
  fi

  if [ -n "$branch" ]; then
    git -C "$path" switch "$branch"
  fi
}

install_git_hooks() {
  for repo in "eirini" "eirini-staging" "eirini-release"; do
    pushd "$HOME/workspace/$repo"
    {
      cp git-hooks/* .git/hooks/
      git init
    }
    popd
  done
}

configure_dotfiles() {
  echo ">>> Installing eirini-home"

  ssh-keyscan -t rsa github.com >>"$HOME/.ssh/known_hosts"

  git_clone "git@github.com:pivotal-cf/git-hooks-core.git"
  git_clone "git@github.com:eirini-forks/eirini-home.git"

  pushd "$HOME/workspace/eirini-home"
  {
    git checkout master
    git pull -r
    ./install.sh
    GIT_DUET_CO_AUTHORED_BY=1 git duet # initialise git-duet
    git init                           # install git-duet hooks on eirini-home
  }
  popd
}

install_vim_plugins() {
  echo ">>> Installing the NeoVim plugins"
  nvim --headless +PlugInstall +PlugUpdate +UpdateRemotePlugins +qall
}

install_misc_tools() {
  echo ">>> Installing Gomega"
  go_get -u "github.com/onsi/gomega"

  echo ">>> Installing Ginkgo"
  go_get -u "github.com/onsi/ginkgo/ginkgo"

  echo ">>> Installing Counterfeiter"
  GO111MODULE=off go_get -u "github.com/maxbrunsfeld/counterfeiter"

  echo ">>> Installing concourse-flake-hunter"
  go_get -u "github.com/masters-of-cats/concourse-flake-hunter"

  echo ">>> Installing fly"
  curl -sL "https://jetson.eirini.cf-app.com/api/v1/cli?arch=amd64&platform=linux" -o "$HOME/bin/fly" && chmod +x "$HOME/bin/fly"

  echo ">>> Installing flightattendant"
  go_get -u "github.com/masters-of-cats/flightattendant"

  echo ">>> Installing k9s (v0.21.4)"
  curl -L https://github.com/derailed/k9s/releases/download/v0.21.4/k9s_Linux_x86_64.tar.gz | tar xvzf - -C "$HOME/bin" k9s

  echo ">>> Installing kind (v0.8.1)"
  curl -L https://github.com/kubernetes-sigs/kind/releases/download/v0.8.1/kind-linux-amd64 -o "$HOME/bin/kind"
  chmod +x "$HOME/bin/kind"

}

go_get() {
  /usr/local/go/bin/go get "$@"
}

init_pass_store() {
  echo ">>> Initialising the pass store"
  mkdir -p "$HOME/.password-store"
  ln -sfn "$HOME/workspace/eirini-private-config/pass/eirini" "$HOME/.password-store/"
  pass init "$(gpg --list-secret-keys | grep -o --color=never "[^<]\+@[^>]\+")"
}

install_pure_zsh_theme() {
  echo ">>> Installing the pure prompt"
  mkdir -p "$HOME/.zsh"
  git_clone "https://github.com/sindresorhus/pure.git" "$HOME/.zsh/pure"
  pushd "$HOME/.zsh/pure"
  {
    git pull -r
  }
  popd
}

switch_to_zsh() {
  echo ">>> Setting Zsh as the default shell"
  sudo chsh -s /bin/zsh "$(whoami)"
}

main $@
