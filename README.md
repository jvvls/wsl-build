# WSL Dev Setup

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

O script `instal.sh` prepara:

- Git
- Zsh + Oh My Zsh
- Docker Engine + Docker Compose
- clientes Postgres e MySQL
- Node.js via NVM
- npm, pnpm e yarn
- TypeScript, ts-node, tsx, ESLint, Prettier, Vite, live-server, htmlhint e stylelint
- SDKMAN
- Java 11, 17 e 21
- Python 3, pip, venv, pipx e Poetry
- Go
- infraestrutura local de bancos via Docker Compose
- aliases e helpers para uso diario

## O que fica no Windows

Instale no Windows:

- VS Code
- DBeaver
- MongoDB Compass
- Windows Terminal

Opcionalmente:

- navegador
- Discord
- Steam
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

Neste repositorio, o script se chama `instal.sh`.

Se quiser rodar direto do GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/jvvls/wsl-build/main/instal.sh | bash
```

Com upgrade de pacotes:

```bash
RUN_APT_UPGRADE=true curl -fsSL https://raw.githubusercontent.com/jvvls/wsl-build/main/instal.sh | bash
```

Se estiver rodando localmente dentro do Ubuntu:

```bash
chmod +x instal.sh
./instal.sh
```

Se quiser atualizar os pacotes do Ubuntu durante a instalacao:

```bash
RUN_APT_UPGRADE=true ./instal.sh
```

Variaveis uteis:

- `RUN_APT_UPGRADE=true`: roda `apt upgrade`
- `CONFIGURE_WSL=false`: nao mexe no `/etc/wsl.conf`
- `FORCE_GO_INSTALL=true`: forca reinstalacao do Go

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
