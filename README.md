# KDE Widget — Controle do Ar Condicionado

Este projeto contém um backend Python (Flask) e um Widget KDE Plasma 6 para controlar um Ar Condicionado (Elgin/Tuya) via protocolo local (TinyTuya), direto da sua bandeja do sistema (System Tray).

## Arquitetura
1. **app.py**: Servidor REST que faz a ponte com o seu ar condicionado (usa _TinyTuya_).
2. **plasmoid/**: O código em QML do widget do KDE Plasma.

## Como instalar

### 1. Iniciar o Backend
Abra um terminal na pasta do projeto e rode:

```bash
# Cria o ambiente virtual e instala as dependências
python3 -m venv venv
venv/bin/pip install flask tinytuya

# Opcional (se já configurado pelo start.fish):
./start.fish
```
O backend ficará rodando na porta `5000`.

### 2. Instalar o Widget no KDE Plasma
No mesmo diretório do projeto, execute:

```bash
kpackagetool6 --type Plasma/Applet --install ./plasmoid
```

Para aplicar as alterações e fazer o widget aparecer:
```bash
plasmashell --replace &; disown
```

### 3. Ativar o Widget
Clique com o **botão direito** na sua barra de tarefas/bandeja do sistema, vá em **Configurar Bandeja do Sistema...**, procure por **"Ar Condicionado"** na aba **Entradas Extras** e mude para **Sempre visível** ou **Ativado**.

## Controle de Versão (Git)
Este projeto já está configurado com `git`. Para enviá-lo para o GitHub crie um repositório lá e em seguida rode:

```bash
git branch -M main
git remote add origin git@github.com:seu-usuario/seu-repositorio.git
git push -u origin main
```
