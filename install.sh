#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# WSL/Linux Dev Environment Installer
# Target: Ubuntu on WSL2
# ============================================================
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/install.sh | bash
#
# Optional:
#   curl -fsSL ... | RUN_APT_UPGRADE=true bash
#   curl -fsSL ... | CONFIGURE_WSL=false bash
#   curl -fsSL ... | FORCE_GO_INSTALL=true bash
#
# Philosophy:
#   - WSL: código, runtimes, Docker, bancos, terminal.
#   - Windows: VS Code, DBeaver, MongoDB Compass, navegador e apps gráficos.
#
# ============================================================

RUN_APT_UPGRADE="${RUN_APT_UPGRADE:-false}"
CONFIGURE_WSL="${CONFIGURE_WSL:-true}"
FORCE_GO_INSTALL="${FORCE_GO_INSTALL:-false}"

DEV_DIR="${DEV_DIR:-$HOME/dev}"
INFRA_DIR="$DEV_DIR/_infra"

log() {
  printf "\n\033[1;34m[dev-setup]\033[0m %s\n" "$1"
}

warn() {
  printf "\n\033[1;33m[warning]\033[0m %s\n" "$1"
}

error() {
  printf "\n\033[1;31m[error]\033[0m %s\n" "$1"
  exit 1
}

require_not_root() {
  if [ "${EUID}" -eq 0 ]; then
    error "Não rode este script como root. Rode como seu usuário normal do WSL."
  fi
}

require_ubuntu() {
  if [ ! -f /etc/os-release ]; then
    error "Não consegui identificar a distro."
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  if [ "${ID:-}" != "ubuntu" ]; then
    error "Este script foi feito para Ubuntu/WSL. Distro detectada: ${PRETTY_NAME:-desconhecida}"
  fi
}

sudo_keepalive() {
  log "Pedindo sudo uma vez no começo..."
  sudo -v

  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
}

append_shell_block() {
  local file="$1"
  local marker="$2"
  local content="$3"

  touch "$file"

  if ! grep -qF "$marker" "$file"; then
    {
      echo ""
      echo "# >>> $marker"
      printf "%s\n" "$content"
      echo "# <<< $marker"
    } >> "$file"
  fi
}

upsert_shell_block() {
  local file="$1"
  local marker="$2"
  local content="$3"
  local temp_file

  touch "$file"

  if grep -qF "# >>> $marker" "$file"; then
    temp_file="$(mktemp)"
    awk -v marker="$marker" -v content="$content" '
      $0 == "# >>> " marker {
        print
        print content
        in_block = 1
        next
      }
      $0 == "# <<< " marker {
        in_block = 0
        print
        next
      }
      !in_block {
        print
      }
    ' "$file" > "$temp_file"
    cat "$temp_file" > "$file"
    rm -f "$temp_file"
  else
    append_shell_block "$file" "$marker" "$content"
  fi
}

is_wsl() {
  grep -qiE "microsoft|wsl" /proc/version 2>/dev/null
}

configure_wsl() {
  local wsl_default_user=""

  if [ "$CONFIGURE_WSL" != "true" ]; then
    warn "Pulando configuração do /etc/wsl.conf porque CONFIGURE_WSL=false."
    return
  fi

  if ! is_wsl; then
    warn "Não parece ser WSL. Pulando configuração específica de WSL."
    return
  fi

  log "Configurando WSL com systemd e isolamento do PATH do Windows..."

  if [ -f /etc/wsl.conf ]; then
    sudo cp /etc/wsl.conf "/etc/wsl.conf.bak.$(date +%Y%m%d%H%M%S)"
    wsl_default_user="$(
      awk '
        /^\[/ {
          in_user = ($0 == "[user]")
          next
        }
        in_user && /^[[:space:]]*default[[:space:]]*=/ {
          sub(/^[^=]*=[[:space:]]*/, "")
          gsub(/[[:space:]]+$/, "")
          print
          exit
        }
      ' /etc/wsl.conf
    )"
  fi

  {
    cat <<'EOF'
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=false
EOF

    if [ -n "$wsl_default_user" ]; then
      printf "\n[user]\ndefault=%s\n" "$wsl_default_user"
    fi
  } | sudo tee /etc/wsl.conf >/dev/null

  warn "O systemd e o isolamento do PATH só entram 100% em vigor depois de rodar 'wsl --shutdown' no Windows."
}

install_base_packages() {
  log "Atualizando APT e instalando pacotes base..."

  sudo apt-get update

  if [ "$RUN_APT_UPGRADE" = "true" ]; then
    sudo apt-get upgrade -y
  fi

  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    unzip \
    zip \
    tar \
    gzip \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    make \
    pkg-config \
    jq \
    vim \
    nano \
    tree \
    htop \
    zsh \
    fonts-powerline \
    python3 \
    python3-pip \
    python3-venv \
    pipx \
    postgresql-client \
    mysql-client
}

configure_git() {
  log "Configurando Git básico para ambiente Linux..."

  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.autocrlf input
  git config --global core.eol lf

  warn "Não configurei user.name nem user.email para não hardcodar seus dados num script público."
  warn "Depois rode: git config --global user.name \"Seu Nome\" && git config --global user.email \"seu@email.com\""
}

install_oh_my_zsh() {
  log "Instalando Oh My Zsh..."

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    log "Oh My Zsh já está instalado."
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
      "$zsh_custom/plugins/zsh-autosuggestions"
  fi

  if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "$zsh_custom/plugins/zsh-syntax-highlighting"
  fi

  if [ -f "$HOME/.zshrc" ]; then
    if grep -q '^plugins=' "$HOME/.zshrc"; then
      sed -i 's/^plugins=.*/plugins=(git docker docker-compose npm node python pip golang zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
    else
      echo 'plugins=(git docker docker-compose npm node python pip golang zsh-autosuggestions zsh-syntax-highlighting)' >> "$HOME/.zshrc"
    fi
  fi

  if command -v zsh >/dev/null 2>&1; then
    sudo chsh -s "$(command -v zsh)" "$USER" || true
  fi
}

install_docker() {
  log "Instalando Docker Engine dentro do Ubuntu/WSL..."

  # shellcheck disable=SC1091
  . /etc/os-release

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo rm -f /etc/apt/keyrings/docker.gpg

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update

  sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  sudo usermod -aG docker "$USER"

  if [ -d /run/systemd/system ]; then
    sudo systemctl enable --now docker || true
  else
    sudo service docker start || true
  fi

  warn "Seu usuário foi adicionado ao grupo docker. Isso só vale em novas sessões do WSL."
}

install_nvm_node() {
  log "Instalando NVM, Node.js LTS e ferramentas JS/TS..."

  if [ ! -d "$HOME/.nvm/.git" ]; then
    git clone https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
  fi

  (
    cd "$HOME/.nvm"
    git fetch --tags --quiet
    latest_tag="$(git describe --abbrev=0 --tags)"
    git checkout "$latest_tag" --quiet
  )

  export NVM_DIR="$HOME/.nvm"

  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default

  npm install -g \
    typescript \
    ts-node \
    tsx \
    pnpm \
    yarn \
    eslint \
    prettier \
    vite \
    serve \
    live-server \
    htmlhint \
    stylelint

  local nvm_block
  nvm_block='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

  append_shell_block "$HOME/.zshrc" "WSL DEV ENV - NVM" "$nvm_block"
  append_shell_block "$HOME/.bashrc" "WSL DEV ENV - NVM" "$nvm_block"
}

install_sdkman_java() {
  log "Instalando SDKMAN e JDKs 11, 17 e 21..."

  if [ ! -d "$HOME/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
  fi

  # shellcheck disable=SC1091
  source "$HOME/.sdkman/bin/sdkman-init.sh"

  mkdir -p "$HOME/.sdkman/etc"

  if [ -f "$HOME/.sdkman/etc/config" ]; then
    sed -i 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "$HOME/.sdkman/etc/config" || true
    sed -i 's/sdkman_auto_selfupdate=false/sdkman_auto_selfupdate=true/g' "$HOME/.sdkman/etc/config" || true
  fi

  sdk selfupdate force || true
  sdk flush candidates || true
  sdk flush archives || true

  install_java_major() {
    local major="$1"
    local version

    version="$(
      sdk list java | \
      sed 's/\x1b\[[0-9;]*m//g' | \
      awk -F'|' -v major="$major" '
        $1 ~ /Temurin/ {
          gsub(/^[ \t]+|[ \t]+$/, "", $3)
          gsub(/^[ \t]+|[ \t]+$/, "", $6)
          if ($3 ~ "^" major "\\.") {
            print $6
            exit
          }
        }
      '
    )"

    if [ -z "$version" ]; then
      warn "Não consegui encontrar automaticamente uma JDK Temurin $major no SDKMAN."
      return
    fi

    if [ -d "$HOME/.sdkman/candidates/java/$version" ]; then
      log "Java $version já está instalado."
    else
      log "Instalando Java $version..."
      sdk install java "$version"
    fi

    if [ "$major" = "21" ]; then
      sdk default java "$version"
    fi
  }

  install_java_major 11
  install_java_major 17
  install_java_major 21

  local sdkman_block
  sdkman_block='export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"'

  append_shell_block "$HOME/.zshrc" "WSL DEV ENV - SDKMAN" "$sdkman_block"
  append_shell_block "$HOME/.bashrc" "WSL DEV ENV - SDKMAN" "$sdkman_block"
}

install_python_tools() {
  log "Configurando Python 3, venv, pip e pipx..."

  python3 -m pip install --user --upgrade pip setuptools wheel

  pipx ensurepath || true

  if command -v pipx >/dev/null 2>&1; then
    pipx install poetry || pipx upgrade poetry || true
  fi

  local python_block
  python_block='export PATH="$HOME/.local/bin:$PATH"
alias py="python3"
alias mkvenv="python3 -m venv .venv"
alias activate="source .venv/bin/activate"'

  append_shell_block "$HOME/.zshrc" "WSL DEV ENV - PYTHON" "$python_block"
  append_shell_block "$HOME/.bashrc" "WSL DEV ENV - PYTHON" "$python_block"
}

install_go() {
  log "Instalando Go pela distribuição oficial..."

  if [ -x /usr/local/go/bin/go ] && [ "$FORCE_GO_INSTALL" != "true" ]; then
    log "Go já está instalado em /usr/local/go. Use FORCE_GO_INSTALL=true para reinstalar."
  else
    local go_arch

    case "$(uname -m)" in
      x86_64)
        go_arch="amd64"
        ;;
      aarch64|arm64)
        go_arch="arm64"
        ;;
      *)
        error "Arquitetura não suportada automaticamente para Go: $(uname -m)"
        ;;
    esac

    local go_file

    go_file="$(
      GO_ARCH="$go_arch" python3 - <<'PY'
import json
import os
import sys
import urllib.request

arch = os.environ["GO_ARCH"]
url = "https://go.dev/dl/?mode=json"

with urllib.request.urlopen(url) as response:
    data = json.load(response)

stable = next(item for item in data if item.get("stable"))

for file in stable["files"]:
    if file.get("os") == "linux" and file.get("arch") == arch and file.get("kind") == "archive":
        print(file["filename"])
        sys.exit(0)

sys.exit("No matching Go archive found")
PY
    )"

    log "Baixando $go_file..."

    curl -fsSLo "/tmp/$go_file" "https://go.dev/dl/$go_file"

    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/$go_file"
    rm -f "/tmp/$go_file"
  fi

  mkdir -p "$HOME/go/bin"

  local go_block
  go_block='export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
export GOPATH="$HOME/go"'

  append_shell_block "$HOME/.zshrc" "WSL DEV ENV - GO" "$go_block"
  append_shell_block "$HOME/.bashrc" "WSL DEV ENV - GO" "$go_block"
}

create_dev_infra() {
  log "Criando infra local de bancos em Docker Compose..."

  mkdir -p "$INFRA_DIR"

  cat > "$INFRA_DIR/docker-compose.yml" <<'EOF'
name: local-dev-databases

services:
  postgres:
    image: postgres:17
    container_name: dev-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-dev}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-dev}
      POSTGRES_DB: ${POSTGRES_DB:-dev}
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  mysql:
    image: mysql:8.4
    container_name: dev-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-dev}
      MYSQL_USER: ${MYSQL_USER:-dev}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-dev}
    ports:
      - "127.0.0.1:3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

  mongo:
    image: mongo:8
    container_name: dev-mongo
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USER:-root}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD:-root}
      MONGO_INITDB_DATABASE: ${MONGO_INITDB_DATABASE:-dev}
    ports:
      - "127.0.0.1:27017:27017"
    volumes:
      - mongo_data:/data/db

volumes:
  postgres_data:
  mysql_data:
  mongo_data:
EOF

  cat > "$INFRA_DIR/.env.example" <<'EOF'
POSTGRES_USER=dev
POSTGRES_PASSWORD=dev
POSTGRES_DB=dev

MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=dev
MYSQL_USER=dev
MYSQL_PASSWORD=dev

MONGO_ROOT_USER=root
MONGO_ROOT_PASSWORD=root
MONGO_INITDB_DATABASE=dev
EOF

  if [ ! -f "$INFRA_DIR/.env" ]; then
    cp "$INFRA_DIR/.env.example" "$INFRA_DIR/.env"
  fi

  cat > "$INFRA_DIR/.gitignore" <<'EOF'
.env
EOF

  cat > "$INFRA_DIR/start-dbs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose up -d
docker compose ps
EOF

  cat > "$INFRA_DIR/stop-dbs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose down
EOF

  cat > "$INFRA_DIR/logs-dbs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose logs -f
EOF

  cat > "$INFRA_DIR/reset-dbs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
echo "Isso vai apagar os volumes locais dos bancos."
read -rp "Digite RESET para confirmar: " confirm
if [ "$confirm" != "RESET" ]; then
  echo "Cancelado."
  exit 0
fi
docker compose down -v
docker compose up -d
docker compose ps
EOF

  chmod +x "$INFRA_DIR/"*.sh
}

create_windows_helpers() {
  log "Criando helpers para interação Windows <-> WSL..."

  local windows_block
  windows_block='codew() {
  local candidates=(
    "/mnt/c/Users/$USER/AppData/Local/Programs/Microsoft VS Code/bin/code"
    "/mnt/c/Program Files/Microsoft VS Code/bin/code"
    "/mnt/c/Program Files (x86)/Microsoft VS Code/bin/code"
  )

  local c
  for c in "${candidates[@]}"; do
    if [ -f "$c" ]; then
      "$c" "$@"
      return $?
    fi
  done

  local found
  found="$(find /mnt/c/Users -maxdepth 5 -type f -path "*/AppData/Local/Programs/Microsoft VS Code/bin/code" 2>/dev/null | head -n 1)"

  if [ -n "$found" ]; then
    "$found" "$@"
    return $?
  fi

  echo "VS Code do Windows não encontrado."
  echo "Instale o VS Code no Windows ou rode pelo Windows Terminal."
  return 1
}

explorerw() {
  /mnt/c/Windows/explorer.exe "$(wslpath -w "${1:-.}")"
}

openw() {
  /mnt/c/Windows/System32/cmd.exe /c start "" "$(wslpath -w "${1:-.}")" >/dev/null 2>&1
}'

  append_shell_block "$HOME/.zshrc" "WSL DEV ENV - WINDOWS HELPERS" "$windows_block"
  append_shell_block "$HOME/.bashrc" "WSL DEV ENV - WINDOWS HELPERS" "$windows_block"
}

create_dev_doctor() {
  log "Criando script de diagnóstico do ambiente..."

  mkdir -p "$HOME/.local/bin"

  cat > "$HOME/.local/bin/dev-doctor" <<'EOF'
#!/usr/bin/env bash

set +e

echo
echo "=============================="
echo " Dev Environment Doctor"
echo "=============================="
echo

echo "[System]"
uname -a
echo

echo "[WSL]"
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  echo "Running inside WSL"
else
  echo "Not detected as WSL"
fi
echo

echo "[Shell]"
echo "SHELL=$SHELL"
zsh --version 2>/dev/null
echo

echo "[Git]"
git --version
echo "user.name=$(git config --global --get user.name)"
echo "user.email=$(git config --global --get user.email)"
echo

echo "[Docker]"
docker --version
docker compose version
docker ps
echo

echo "[Node]"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
node -v
npm -v
pnpm -v
tsc -v
echo

echo "[Java / SDKMAN]"
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
java -version
sdk current java
echo

echo "[Python]"
python3 --version
pip3 --version
pipx --version
poetry --version
echo

echo "[Go]"
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
go version
echo

echo "[DB Clients]"
psql --version
mysql --version
echo

echo "[Local DB Compose]"
if [ -f "$HOME/dev/_infra/docker-compose.yml" ]; then
  cd "$HOME/dev/_infra" && docker compose ps
else
  echo "Infra local não encontrada em ~/dev/_infra."
fi
echo

echo "[Windows helpers]"
type codew >/dev/null 2>&1 && echo "codew disponível" || echo "codew não carregado nesta sessão"
type explorerw >/dev/null 2>&1 && echo "explorerw disponível" || echo "explorerw não carregado nesta sessão"
echo
EOF

  chmod +x "$HOME/.local/bin/dev-doctor"
}

create_aliases() {
  log "Criando aliases úteis..."

  local aliases_block
  aliases_block='alias ll="ls -lah"
alias dev="cd ~/dev"
alias infra="cd ~/dev/_infra"
alias dbs-up="cd ~/dev/_infra && ./start-dbs.sh"
alias dbs-down="cd ~/dev/_infra && ./stop-dbs.sh"
alias dbs-logs="cd ~/dev/_infra && ./logs-dbs.sh"
alias dbs-reset="cd ~/dev/_infra && ./reset-dbs.sh"
alias dc="docker compose"
alias dps="docker ps"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias psql-dev="psql postgresql://dev:dev@localhost:5432/dev"
alias mysql-dev="mysql -h 127.0.0.1 -P 3306 -u dev -pdev dev"
alias mongosh-dev="docker exec -it dev-mongo mongosh -u root -p root --authenticationDatabase admin"'

  append_shell_block "$HOME/.zshrc" "WSL DEV ENV - ALIASES" "$aliases_block"
  append_shell_block "$HOME/.bashrc" "WSL DEV ENV - ALIASES" "$aliases_block"
}

final_message() {
  log "Setup finalizado."

  cat <<EOF

Próximos passos:

1. Feche o terminal do WSL.

2. No PowerShell do Windows, rode:

   wsl --shutdown

3. Abra o Ubuntu/WSL de novo.

4. Entre no Zsh:

   zsh

5. Suba os bancos locais:

   dbs-up

6. Rode o diagnóstico:

   dev-doctor

Conexões dos bancos para apps no Windows:

Postgres no DBeaver:
  Host: localhost
  Port: 5432
  Database: dev
  User: dev
  Password: dev

MySQL no DBeaver:
  Host: localhost
  Port: 3306
  Database: dev
  User: dev
  Password: dev
  Root password: root

MongoDB no MongoDB Compass:
  mongodb://root:root@localhost:27017/?authSource=admin

Helpers úteis:

  codew .
    Abre o VS Code do Windows no diretório atual do WSL.

  explorerw .
    Abre o diretório atual no Explorer do Windows.

  openw .
    Abre o caminho atual com o app padrão do Windows.

Git ainda precisa dos seus dados:

  git config --global user.name "Seu Nome"
  git config --global user.email "seu@email.com"

EOF
}

main() {
  require_not_root
  require_ubuntu
  sudo_keepalive

  mkdir -p "$DEV_DIR"

  configure_wsl
  install_base_packages
  configure_git
  install_oh_my_zsh
  install_docker
  install_nvm_node
  install_sdkman_java
  install_python_tools
  install_go
  create_dev_infra
  create_windows_helpers
  create_dev_doctor
  create_aliases
  final_message
}

main "$@"
