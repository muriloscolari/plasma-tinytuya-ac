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
O backend ficará rodando na porta `8456`.

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

### 4. Rodar o Backend como Serviço (Systemd Daemon)
Para que a API inicie automaticamente com seu sistema sem precisar deixar um terminal aberto, você pode criar um serviço de usuário no `systemd`.

1. Crie o diretório para serviços de usuário (se não existir):
   ```bash
   mkdir -p ~/.config/systemd/user
   ```

2. Crie o arquivo do serviço:
   ```bash
   nano ~/.config/systemd/user/arcontrol.service
   ```

3. Cole a seguinte configuração (substitua o caminho se seu projeto estiver em outro local):
   ```ini
   [Unit]
   Description=Ar Condicionado API Backend
   
   [Service]
   WorkingDirectory=%h/Documentos/widgetControle
   ExecStart=/usr/bin/fish %h/Documentos/widgetControle/start.fish
   Restart=always
   
   [Install]
   WantedBy=default.target
   ```

4. Recarregue o systemd e ative o serviço:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now arcontrol.service
   ```

Para ver os logs do backend a qualquer momento: `journalctl --user -fu arcontrol`
