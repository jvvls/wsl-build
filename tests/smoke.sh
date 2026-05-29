#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"
WINDOWS_PS1="$ROOT_DIR/windows/setp-windows.ps1"
VALIDATE_WINDOWS_PS1="$ROOT_DIR/tests/validate-windows.ps1"
VALIDATE_WSL_SH="$ROOT_DIR/tests/validate-wsl.sh"
README="$ROOT_DIR/README.md"

passed=0
skipped=0

ok() {
  passed=$((passed + 1))
  printf '[ok] %s\n' "$1"
}

skip() {
  skipped=$((skipped + 1))
  printf '[skip] %s\n' "$1"
}

fail() {
  printf '[fail] %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -qF -- "$pattern" "$file"; then
    ok "$message"
  else
    fail "$message"
  fi
}

assert_file_matches() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    ok "$message"
  else
    fail "$message"
  fi
}

bash -n "$INSTALL_SH"
ok "install.sh tem sintaxe Bash valida"

bash -n "$VALIDATE_WSL_SH"
ok "validate-wsl.sh tem sintaxe Bash valida"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile('$WINDOWS_PS1', [ref]\$null, [ref]\$errors); if (\$errors.Count -gt 0) { \$errors | ForEach-Object { Write-Error \$_.Message }; exit 1 }"
  ok "setp-windows.ps1 tem sintaxe PowerShell valida"
  pwsh -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile('$VALIDATE_WINDOWS_PS1', [ref]\$null, [ref]\$errors); if (\$errors.Count -gt 0) { \$errors | ForEach-Object { Write-Error \$_.Message }; exit 1 }"
  ok "validate-windows.ps1 tem sintaxe PowerShell valida"
else
  skip "pwsh nao encontrado; validacao sintatica PowerShell pulada"
fi

assert_file_contains "$INSTALL_SH" 'local wsl_default_user=""' "install.sh preserva usuario default do WSL"
assert_file_contains "$INSTALL_SH" '[user]\ndefault=%s\n' "install.sh reescreve secao [user] quando existente"

assert_file_contains "$WINDOWS_PS1" 'function Test-NvidiaGpu' "Windows tem funcao de deteccao NVIDIA"
assert_file_contains "$WINDOWS_PS1" 'Win32_VideoController' "Deteccao NVIDIA consulta adaptadores de video"
assert_file_contains "$WINDOWS_PS1" 'Win32_PnPEntity' "Deteccao NVIDIA consulta dispositivos PnP"
assert_file_contains "$WINDOWS_PS1" 'VEN_10DE' "Deteccao NVIDIA usa vendor PCI NVIDIA"
assert_file_matches "$WINDOWS_PS1" 'auto\|detect\|detectar' "Parametro InstallNvidiaTools aceita modo automatico explicito"
assert_file_contains "$WINDOWS_PS1" 'Deseja habilitar e configurar o WSL agora?' "Windows pergunta antes de configurar WSL por padrao"

assert_file_contains "$WINDOWS_PS1" 'NOPASSWD:ALL' "Windows cria sudo temporario para bootstrap"
assert_file_contains "$WINDOWS_PS1" 'rm -f /etc/sudoers.d/$safeUser-bootstrap' "Windows remove sudo temporario ao final"
assert_file_contains "$WINDOWS_PS1" 'Assert-NativeSuccess' "Windows verifica exit code de comandos nativos"

assert_file_contains "$README" '-InstallNvidiaTools auto' "README documenta modo NVIDIA automatico"
assert_file_contains "$README" 'Sem informar `-ConfigureWsl`, o script pergunta' "README documenta prompt padrao do WSL"
assert_file_contains "$README" '- `-ConfigureWsl $true`: habilita e configura o WSL sem perguntar' "README documenta forcar WSL sem prompt"
assert_file_contains "$README" './tests/validate-wsl.sh' "README documenta validador WSL"
assert_file_contains "$README" 'validate-windows.ps1' "README documenta validador Windows"
assert_file_contains "$VALIDATE_WSL_SH" 'expected_home="/home/$(whoami)"' "validador WSL confere HOME em /home/usuario"
assert_file_contains "$VALIDATE_WSL_SH" 'PATH nao contem caminhos do Windows' "validador WSL confere PATH sem Windows"
assert_file_contains "$VALIDATE_WSL_SH" 'check_command_not_windows_path node' "validador WSL confere binarios fora de /mnt"
assert_file_contains "$VALIDATE_WSL_SH" 'sdk current java responde' "validador WSL consulta Java atual no SDKMAN"
assert_file_contains "$VALIDATE_WINDOWS_PS1" 'HOME do WSL esta no filesystem Linux' "validador Windows confere HOME do WSL"

printf '\nSmoke tests passaram: %s ok, %s skip\n' "$passed" "$skipped"
