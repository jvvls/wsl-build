# WSL Dev Setup

Rodar o script completo com:
```text
irm https://raw.githubusercontent.com/jvvls/wsl-build/main/windows/setp-windows.ps1 | iex
```

Setup de desenvolvimento com:

- Windows para interface grafica e apps do dia a dia
- WSL2 com Ubuntu para terminal, runtimes, Docker e bancos locais

Repositorio:

```text
https://github.com/jvvls/wsl-build
```

## Objetivo

A ideia deste ambiente e separar bem os papeis:

- Windows: VS Code, DBeaver, MongoDB Compass, navegador e apps graficos
- WSL/Ubuntu: codigo, Git, linguagens, dependencias, Docker e banco local

Isso evita mistura de ferramentas Windows com ferramentas Linux e deixa o fluxo mais previsivel.

## O que este setup instala no WSL

O script `install.sh` prepara:

- Git
- Zsh + Oh My Zsh
- Docker Engine + Docker Compose
- clientes Postgres e MySQL
- Node.js via NVM
- npm, pnpm e yarn
- TypeScript, ts-node, tsx, ESLint, Prettier, Vite, live-server, htmlhint e stylelint
- SDKMAN
- Java 11, 17 e 21
- Apache Spark para ETL, como instalacao opcional
- Python 3, pip, venv, pipx e Poetry
- Go
- infraestrutura local de bancos via Docker Compose
- aliases e helpers para uso diario

## O que fica no Windows

O setup automatico do Windows instala e configura:

- VS Code
- DBeaver
- MongoDB Compass
- Windows Terminal
- PowerShell 7
- Git
- GitHub CLI
- Brave
- Docker Desktop
- PowerToys
- AutoHotkey v2
- Flow Launcher
- TrafficMonitor
- HWiNFO
- GlazeWM

Opcionalmente:

- Discord
- Steam
- Stremio
- VLC
- ferramentas NVIDIA
- outros apps normais do sistema

## Estrutura recomendada

Mantenha seus projetos dentro do Linux:

```bash
~/dev
```

Infra local:

```bash
~/dev/_infra
```

Evite trabalhar em:

```bash
/mnt/c/Users/...
```

## Instalacao automatica do Windows

O script `windows/setp-windows.ps1` prepara uma instalacao nova do Windows 11 para usar o Windows como interface grafica e o WSL como ambiente principal de desenvolvimento.

Rode em um PowerShell aberto como Administrador:

```powershell
irm https://raw.githubusercontent.com/jvvls/wsl-build/main/windows/setp-windows.ps1 | iex
```

O script faz, em ordem geral:

- cria ponto de restauracao antes das mudancas
- verifica se o `winget` esta disponivel
- instala apps base e ferramentas de desenvolvimento pelo `winget`
- aplica um debloat conservador do Windows 11
- configura Git basico no Windows
- cria arquivos de configuracao em `%USERPROFILE%\dev-setup\windows`
- instala e inicia os keybinds do AutoHotkey
- configura GlazeWM como window manager
- habilita recursos do WSL2
- instala a distro Ubuntu, se ainda nao existir
- cria o usuario Linux baseado no usuario do Windows
- roda o setup do WSL com `install.sh`
- registra continuacao automatica apos reboot quando necessario
- salva logs em `%USERPROFILE%\dev-setup-logs`

### Parametros uteis

Para customizar, baixe o script e rode com parametros:

```powershell
New-Item -ItemType Directory -Force -Path $env:USERPROFILE\dev-setup
iwr https://raw.githubusercontent.com/jvvls/wsl-build/main/windows/setp-windows.ps1 -OutFile $env:USERPROFILE\dev-setup\setp-windows.ps1
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\dev-setup\setp-windows.ps1 -InstallGamingApps $false -InstallNvidiaTools $false
```

Parametros principais:

- `-WslDistro Ubuntu`: distro usada pelo WSL
- `-WslSetupUrl <url>`: URL do script Linux que sera executado dentro do WSL
- `-DotfilesRepo <url>`: clona dotfiles no Windows e no WSL
- `-UseWin11Debloat $false`: pula o Win11Debloat externo
- `-InstallNvidiaTools $false`: pula ferramentas NVIDIA
- `-InstallGamingApps $false`: pula Steam, Discord, Stremio, VLC e runtimes de jogos
- `-InstallDevGuiApps $false`: pula apps graficos de desenvolvimento
- `-InstallWindowManager $false`: pula GlazeWM
- `-ConfigureWsl $false`: nao habilita nem configura WSL
- `-RemoveOneDrive $true`: remove OneDrive
- `-AutoReboot $true`: reinicia automaticamente quando o Windows pedir

### Reboot e retomada

Algumas etapas do WSL podem exigir reboot. Quando isso acontece, o script registra uma entrada `RunOnce` chamada `JalDevSetupResume` para continuar na proxima sessao.

Se preferir fazer manualmente:

```powershell
Restart-Computer
```

Depois do reboot, rode o script novamente como Administrador ou deixe a retomada automatica executar.

### Arquivos gerados no Windows

```text
%USERPROFILE%\dev-setup\windows\ahk\jal-hotkeys.ahk
%USERPROFILE%\.glzr\glazewm\config.yaml
%USERPROFILE%\dev-setup-logs\setup-windows-*.log
```

## Keybinds personalizados

O setup configura dois grupos de atalhos:

- AutoHotkey: atalhos globais com `CapsLock` como tecla leader
- GlazeWM: atalhos de foco, workspace, tiling, resize e apps

### AutoHotkey

`CapsLock` fica sempre desligado e passa a funcionar como leader.

| Atalho | Acao |
| --- | --- |
| `CapsLock + t` | abre Windows Terminal |
| `CapsLock + b` | abre Brave |
| `CapsLock + d` | abre Discord |
| `CapsLock + s` | abre Steam |
| `CapsLock + e` | abre Explorer |
| `CapsLock + c` | abre VS Code |
| `CapsLock + f` | abre Flow Launcher |
| `CapsLock + p` | abre PowerShell |
| `CapsLock + q` | fecha a janela ativa |
| `CapsLock + x` | encerra o processo da janela ativa |
| `CapsLock + r` | recarrega o arquivo de hotkeys |
| `CapsLock + o` | abre a pasta de configs do setup |

### GlazeWM

#### Navegacao de janelas

| Atalho | Acao |
| --- | --- |
| `Alt + h` ou `Alt + Left` | foco para a esquerda |
| `Alt + l` ou `Alt + Right` | foco para a direita |
| `Alt + k` ou `Alt + Up` | foco para cima |
| `Alt + j` ou `Alt + Down` | foco para baixo |
| `Alt + Shift + h` ou `Alt + Shift + Left` | move janela para a esquerda |
| `Alt + Shift + l` ou `Alt + Shift + Right` | move janela para a direita |
| `Alt + Shift + k` ou `Alt + Shift + Up` | move janela para cima |
| `Alt + Shift + j` ou `Alt + Shift + Down` | move janela para baixo |

#### Resize e modos

| Atalho | Acao |
| --- | --- |
| `Alt + u` | diminui largura |
| `Alt + p` | aumenta largura |
| `Alt + o` | aumenta altura |
| `Alt + i` | diminui altura |
| `Alt + r` | entra no modo resize |
| `h`, `l`, `k`, `j` no modo resize | redimensiona a janela |
| `Esc`, `Enter` ou `Alt + r` no modo resize | sai do modo resize |
| `Alt + Shift + Space` | alterna floating centralizado |
| `Alt + t` | alterna tiling |
| `Alt + f` | alterna fullscreen |
| `Alt + m` | minimiza |
| `Alt + Shift + q` | fecha janela |

#### Comandos do GlazeWM

| Atalho | Acao |
| --- | --- |
| `Alt + Shift + r` | recarrega configuracao |
| `Alt + Shift + w` | redesenha janelas |
| `Alt + Shift + p` | pausa ou retoma o window manager |
| `Alt + Shift + e` | encerra o GlazeWM |

#### Apps rapidos

| Atalho | Acao |
| --- | --- |
| `Alt + Enter` | abre Windows Terminal |
| `Alt + b` | abre Brave |
| `Alt + c` | abre VS Code |
| `Alt + e` | abre Explorer |

#### Workspaces

| Atalho | Acao |
| --- | --- |
| `Alt + 1..9` | muda para o workspace |
| `Alt + Shift + 1..9` | move a janela para o workspace e foca nele |
| `Alt + s` | vai para o proximo workspace ativo |
| `Alt + a` | vai para o workspace ativo anterior |
| `Alt + d` | volta ao workspace recente |
| `Alt + Shift + a` | move o workspace para a esquerda |
| `Alt + Shift + d` | move o workspace para a direita |

Workspaces padrao:

| Numero | Nome | Uso |
| --- | --- | --- |
| `1` | `DEV` | VS Code e Cursor |
| `2` | `WEB` | navegadores |
| `3` | `TERM` | terminais |
| `4` | `DB` | DBeaver e MongoDB Compass |
| `5` | `CHAT` | Discord e Teams |
| `6` | `MEDIA` | Stremio e VLC |
| `7` | `GAME` | Steam |
| `8` | `MISC` | geral |
| `9` | `FLOAT` | janelas soltas |

## 1. Instalar o WSL

No PowerShell:

```powershell
wsl --install -d Ubuntu
wsl --update
wsl -l -v
```

Confirme que o Ubuntu esta em WSL2:

```text
Ubuntu    Running    2
```

## 2. Instalar os apps do Windows

Exemplo com `winget`:

```powershell
winget install -e --id Microsoft.VisualStudioCode
winget install -e --id DBeaver.DBeaver.Community
winget install -e --id MongoDB.Compass.Full
```

## 3. Rodar o script de setup

Neste repositorio, o script se chama `install.sh`.

Se quiser rodar direto do GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/jvvls/wsl-build/main/install.sh | bash
```

Com upgrade de pacotes:

```bash
RUN_APT_UPGRADE=true curl -fsSL https://raw.githubusercontent.com/jvvls/wsl-build/main/install.sh | bash
```

Se estiver rodando localmente dentro do Ubuntu:

```bash
chmod +x install.sh
./install.sh
```

Se quiser atualizar os pacotes do Ubuntu durante a instalacao:

```bash
RUN_APT_UPGRADE=true ./install.sh
```

Variaveis uteis:

- `RUN_APT_UPGRADE=true`: roda `apt upgrade`
- `CONFIGURE_WSL=false`: nao mexe no `/etc/wsl.conf`
- `FORCE_GO_INSTALL=true`: forca reinstalacao do Go
- `INSTALL_SPARK=ask`: pergunta durante a execucao se o Spark deve ser instalado
- `INSTALL_SPARK=true`: instala o Spark sem perguntar
- `INSTALL_SPARK=false`: pula a instalacao do Spark sem perguntar

Ao rodar o script em terminal interativo, ele pergunta se voce quer instalar o Spark para ETL.
Em execucoes nao interativas, como automacao ou quando nao houver terminal disponivel, use `INSTALL_SPARK=true` ou `INSTALL_SPARK=false`.

## 4. Depois da instalacao

No PowerShell:

```powershell
wsl --shutdown
```

Abra o Ubuntu novamente e rode:

```bash
zsh
dev-doctor
```

## Configuracao automatica do WSL

O script configura este arquivo:

```bash
/etc/wsl.conf
```

Conteudo:

```ini
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=false
```

### Por que `appendWindowsPath=false`?

Para evitar misturar executaveis do Windows com os do Linux, como:

- `node.exe`
- `python.exe`
- `java.exe`
- `git.exe`

## Uso com VS Code

Instale a extensao:

```text
WSL
```

Confirme no canto inferior do VS Code:

```text
WSL: Ubuntu
```

Abra projetos com:

```bash
codew .
```

Evite:

```bash
code .
```

## Helpers disponiveis

O script adiciona estes comandos:

```bash
codew .
explorerw .
openw .
dev-doctor
```

O que cada um faz:

- `codew`: abre o VS Code do Windows a partir do WSL
- `explorerw`: abre a pasta atual no Explorer
- `openw`: abre arquivo ou pasta com o app padrao do Windows
- `dev-doctor`: valida o ambiente instalado

## Docker

Verificacao rapida:

```bash
docker ps
docker compose version
```

Status do servico:

```bash
sudo systemctl status docker
```

Se o Docker ainda pedir `sudo`, rode:

```powershell
wsl --shutdown
```

Depois teste novamente:

```bash
docker ps
```

## Infra local dos bancos

Local esperado:

```bash
~/dev/_infra
```

Arquivos gerados:

```text
docker-compose.yml
.env
start-dbs.sh
stop-dbs.sh
logs-dbs.sh
reset-dbs.sh
```

### Comandos da infra

```bash
dbs-up
dbs-down
dbs-logs
dbs-reset
```

## Bancos

### Postgres

```text
Host: localhost
Port: 5432
Database: dev
User: dev
Password: dev
```

Teste:

```bash
psql-dev
```

URL:

```text
postgresql://dev:dev@localhost:5432/dev
```

### MySQL

```text
Host: localhost
Port: 3306
Database: dev
User: dev
Password: dev
```

Root:

```text
User: root
Password: root
```

Teste:

```bash
mysql-dev
```

### MongoDB

URI para o Compass:

```text
mongodb://root:root@localhost:27017/?authSource=admin
```

Teste:

```bash
mongosh-dev
```

## Node.js e NVM

Verificar versoes:

```bash
nvm ls
node -v
npm -v
pnpm -v
```

Instalar ou trocar para a LTS:

```bash
nvm install --lts
nvm use --lts
```

## Ferramentas JavaScript instaladas

- TypeScript
- ts-node
- tsx
- pnpm
- yarn
- ESLint
- Prettier
- Vite
- live-server
- htmlhint
- stylelint

Criar projeto com Vite:

```bash
pnpm create vite
pnpm install
pnpm dev
```

## Java e SDKMAN

Versoes instaladas:

- Java 11
- Java 17
- Java 21

Ver a versao atual:

```bash
sdk current java
java -version
```

Listar versoes:

```bash
sdk list java
```

Trocar de versao:

```bash
sdk use java <versao>
sdk default java <versao>
```

## Spark opcional para ETL

Se voce responder `s` quando o script perguntar sobre o Spark, ele vai:

- baixar o Apache Spark `3.5.1`
- extrair em `~/apps/spark`
- reaproveitar o Java 11 instalado pelo SDKMAN
- adicionar `SPARK_HOME`, `SPARK_JAVA_HOME` e `PATH` no `.bashrc` e no `.zshrc`
- gravar um `spark-env.sh` para o Spark sempre subir com o Java 11 do SDKMAN

Com isso, o Spark roda com Java 11 sem sobrescrever o `JAVA_HOME` global da sua sessao.

Validacao rapida depois de reabrir o terminal:

```bash
spark-submit --version
```

Execucao sem prompt:

```bash
INSTALL_SPARK=true ./instal.sh
```

Ou direto do GitHub:

```bash
INSTALL_SPARK=true curl -fsSL https://raw.githubusercontent.com/jvvls/wsl-build/main/instal.sh | bash
```

## Python

Verificar instalacao:

```bash
python3 --version
pip3 --version
poetry --version
```

Criar e ativar ambiente virtual:

```bash
mkvenv
activate
```

Modo manual:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## Go

Verificar:

```bash
go version
```

`GOPATH` padrao:

```bash
~/go
```

## Git

Configuracoes aplicadas pelo script:

```bash
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input
git config --global core.eol lf
```

Configure seus dados depois:

```bash
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"
```

## SSH para GitHub

Gerar chave:

```bash
ssh-keygen -t ed25519 -C "seu@email.com"
```

Carregar no agent:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Mostrar chave publica:

```bash
cat ~/.ssh/id_ed25519.pub
```

Testar:

```bash
ssh -T git@github.com
```

## Fluxo recomendado

```bash
cd ~/dev
git clone git@github.com:usuario/repositorio.git
cd repositorio
codew .
dbs-up
```

Se seu frontend subir em portas como:

```text
localhost:3000
localhost:5173
localhost:8000
```

Abra normalmente no navegador do Windows.

## O que nao fazer

Nao instale em duplicidade no Windows:

- Node
- Python
- Java

Evite tambem:

- rodar projeto Linux pelo PowerShell
- desenvolver dentro de `/mnt/c/Users/...`
- misturar binarios Windows com Linux no terminal do WSL

## Como validar de onde vem cada comando

```bash
which node
which python3
which java
which git
```

Esses caminhos nao devem apontar para:

```text
/mnt/c/
```

## Troubleshooting

### Docker pede sudo

```powershell
wsl --shutdown
```

### `systemctl` nao funciona

Confirme:

```ini
[boot]
systemd=true
```

Depois:

```powershell
wsl --shutdown
```

### Projeto lento

Mova o repositorio para:

```bash
~/dev
```

### `node_modules` quebrado

```bash
rm -rf node_modules
pnpm install
```

### Validar o ambiente

```bash
dev-doctor
```
