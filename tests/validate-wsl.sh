#!/usr/bin/env bash

set -euo pipefail

WITH_DBS="${WITH_DBS:-false}"
DEV_DIR="${DEV_DIR:-$HOME/dev}"
INFRA_DIR="${INFRA_DIR:-$DEV_DIR/_infra}"

passed=0
failed=0
skipped=0

ok() {
  passed=$((passed + 1))
  printf '[ok] %s\n' "$1"
}

warn_skip() {
  skipped=$((skipped + 1))
  printf '[skip] %s\n' "$1"
}

bad() {
  failed=$((failed + 1))
  printf '[fail] %s\n' "$1" >&2
}

check_command() {
  local command_name="$1"
  local label="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$label encontrado: $(command -v "$command_name")"
  else
    bad "$label nao encontrado no PATH"
  fi
}

check_runs() {
  local label="$1"
  shift

  if "$@" >/tmp/dev-setup-check.out 2>&1; then
    ok "$label"
  else
    bad "$label"
    sed 's/^/  /' /tmp/dev-setup-check.out >&2
  fi
}

check_contains() {
  local label="$1"
  local file="$2"
  local expected="$3"

  if [ -f "$file" ] && grep -qF -- "$expected" "$file"; then
    ok "$label"
  else
    bad "$label"
  fi
}

check_linux_home_path() {
  local label="$1"
  local path="$2"

  case "$path" in
    "$HOME"|"$HOME"/*)
      ok "$label dentro do HOME Linux: $path"
      ;;
    /mnt/*)
      bad "$label esta em caminho montado do Windows: $path"
      ;;
    *)
      bad "$label fora do HOME esperado ($HOME): $path"
      ;;
  esac
}

check_not_windows_path() {
  local label="$1"
  local path="$2"

  case "$path" in
    /mnt/*)
      bad "$label aponta para binario/caminho do Windows: $path"
      ;;
    "")
      bad "$label caminho vazio"
      ;;
    *)
      ok "$label nao usa /mnt: $path"
      ;;
  esac
}

check_command_not_windows_path() {
  local command_name="$1"
  local label="$2"
  local command_path

  command_path="$(command -v "$command_name" 2>/dev/null || true)"
  check_not_windows_path "$label" "$command_path"
}

printf '\n== Sistema ==\n'
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  ok "rodando dentro do WSL"
else
  bad "nao parece estar rodando dentro do WSL"
fi

if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" = "ubuntu" ]; then
    ok "distro Ubuntu detectada: ${PRETTY_NAME:-ubuntu}"
  else
    bad "distro nao suportada: ${PRETTY_NAME:-desconhecida}"
  fi
else
  bad "/etc/os-release nao encontrado"
fi

if [ -f /etc/wsl.conf ]; then
  check_contains "wsl.conf habilita systemd" /etc/wsl.conf "systemd=true"
  check_contains "wsl.conf isola PATH do Windows" /etc/wsl.conf "appendWindowsPath=false"
else
  bad "/etc/wsl.conf nao encontrado"
fi

printf '\n== Paths WSL ==\n'
expected_home="/home/$(whoami)"
if [ "$HOME" = "$expected_home" ]; then
  ok "HOME esperado: $HOME"
else
  bad "HOME esperado $expected_home, atual $HOME"
fi

check_not_windows_path "HOME" "$HOME"
check_linux_home_path "DEV_DIR" "$DEV_DIR"
check_linux_home_path "INFRA_DIR" "$INFRA_DIR"
check_linux_home_path "NVM_DIR esperado" "$HOME/.nvm"
check_linux_home_path "SDKMAN_DIR esperado" "$HOME/.sdkman"
check_linux_home_path "GOPATH esperado" "$HOME/go"

if [ -d "$DEV_DIR" ]; then
  ok "DEV_DIR existe: $DEV_DIR"
else
  bad "DEV_DIR nao existe: $DEV_DIR"
fi

case "$PATH" in
  *"/mnt/c/"*|*"/mnt/c/Windows"*|*"/mnt/c/Program Files"*)
    bad "PATH contem caminhos do Windows apesar do isolamento: $PATH"
    ;;
  *)
    ok "PATH nao contem caminhos do Windows"
    ;;
esac

printf '\n== Base CLI ==\n'
check_command git "Git"
check_command zsh "Zsh"
check_command curl "curl"
check_command wget "wget"
check_command jq "jq"
check_command make "make"
check_command gcc "gcc"

check_runs "git responde" git --version
check_runs "zsh responde" zsh --version
check_command_not_windows_path git "Git"
check_command_not_windows_path zsh "Zsh"

printf '\n== Docker ==\n'
check_command docker "Docker"
check_runs "docker compose responde" docker compose version
check_runs "docker daemon acessivel sem sudo" docker ps
check_command_not_windows_path docker "Docker"

printf '\n== Node / JS ==\n'
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.nvm/nvm.sh"
  ok "NVM carregado"
else
  bad "NVM nao encontrado em ~/.nvm/nvm.sh"
fi

check_command node "Node.js"
check_command npm "npm"
check_command pnpm "pnpm"
check_command yarn "yarn"
check_command tsc "TypeScript"
check_command ts-node "ts-node"
check_command tsx "tsx"
check_command eslint "ESLint"
check_command prettier "Prettier"
check_command vite "Vite"
check_command live-server "live-server"
check_command htmlhint "htmlhint"
check_command stylelint "stylelint"

check_runs "node responde" node --version
check_runs "pnpm responde" pnpm --version
check_command_not_windows_path node "Node.js"
check_command_not_windows_path npm "npm"
check_command_not_windows_path pnpm "pnpm"

printf '\n== Java ==\n'
check_command java "Java"
check_command javac "javac"
check_command_not_windows_path java "Java"
check_command_not_windows_path javac "javac"

if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.sdkman/bin/sdkman-init.sh"
  ok "SDKMAN carregado"
else
  bad "SDKMAN nao encontrado em ~/.sdkman/bin/sdkman-init.sh"
fi

if java -version >/tmp/dev-setup-java.out 2>&1; then
  ok "java responde"
else
  bad "java nao respondeu"
  sed 's/^/  /' /tmp/dev-setup-java.out >&2
fi

if sdk current java >/tmp/dev-setup-sdk-java.out 2>&1; then
  ok "sdk current java responde"
else
  bad "sdk current java nao respondeu"
  sed 's/^/  /' /tmp/dev-setup-sdk-java.out >&2
fi

if [ -n "${JAVA_HOME:-}" ]; then
  check_not_windows_path "JAVA_HOME" "$JAVA_HOME"
else
  warn_skip "JAVA_HOME nao definido nesta sessao"
fi

printf '\n== Python ==\n'
check_command python3 "Python 3"
check_command pip3 "pip3"
check_command pipx "pipx"
check_command poetry "Poetry"
check_runs "python3 responde" python3 --version
check_runs "pip3 responde" pip3 --version
check_runs "poetry responde" poetry --version
check_command_not_windows_path python3 "Python 3"
check_command_not_windows_path pip3 "pip3"
check_command_not_windows_path poetry "Poetry"

tmp_venv="$(mktemp -d)"
if python3 -m venv "$tmp_venv/.venv" && "$tmp_venv/.venv/bin/python" -c 'print("venv ok")' >/dev/null; then
  ok "python venv funciona"
else
  bad "python venv nao funcionou"
fi
rm -rf "$tmp_venv"

printf '\n== Go ==\n'
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
check_command go "Go"
check_runs "go responde" go version
check_command_not_windows_path go "Go"

printf '\n== Bancos / infra local ==\n'
check_command psql "Postgres client"
check_command mysql "MySQL client"

if [ -f "$INFRA_DIR/docker-compose.yml" ]; then
  ok "docker-compose da infra existe em $INFRA_DIR"
  check_linux_home_path "infra local" "$INFRA_DIR"
  check_contains "infra tem Postgres" "$INFRA_DIR/docker-compose.yml" "postgres:"
  check_contains "infra tem MySQL" "$INFRA_DIR/docker-compose.yml" "mysql:"
  check_contains "infra tem MongoDB" "$INFRA_DIR/docker-compose.yml" "mongo:"
else
  bad "docker-compose da infra nao encontrado em $INFRA_DIR"
fi

if [ "$WITH_DBS" = "true" ]; then
  if [ -f "$INFRA_DIR/docker-compose.yml" ]; then
    check_runs "subir bancos locais via Docker Compose" bash -lc "cd '$INFRA_DIR' && docker compose up -d"
    check_runs "listar bancos locais via Docker Compose" bash -lc "cd '$INFRA_DIR' && docker compose ps"
  else
    bad "WITH_DBS=true, mas infra nao existe"
  fi
else
  warn_skip "teste de subir bancos pulado; use WITH_DBS=true ./tests/validate-wsl.sh"
fi

printf '\n== Helpers ==\n'
if grep -qF 'codew()' "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null; then
  ok "helper codew configurado"
else
  bad "helper codew nao encontrado nos arquivos de shell"
fi

if grep -qF 'alias dbs-up=' "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null; then
  ok "aliases da infra configurados"
else
  bad "aliases da infra nao encontrados nos arquivos de shell"
fi

printf '\nResultado: %s ok, %s fail, %s skip\n' "$passed" "$failed" "$skipped"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
