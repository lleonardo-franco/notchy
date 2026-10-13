# Changelog

## 1.0.0

- Janela de boas-vindas com cada permissão, o status dela e um botão para liberar
- Hooks do Claude Code embutidos no app, com status e botão de instalar ou reinstalar nos ajustes
- AppleScript com tempo limite, para um app travado não congelar música, vídeo e terminal
- Verificações pausadas com a tela bloqueada ou o Mac dormindo, e mais espaçadas com o notch fechado
- Escolha de tela (com notch, principal ou só telas com notch) e opção de esconder em apps de tela cheia
- `notchy doctor` com o estado das permissões, `notchy update`, `notchy uninstall`, `notchy welcome` e `notchy version`
- `./install.sh --uninstall`
- README, roteiro de teste, licença e este changelog

## 0.9.1

- Vídeos do YouTube também no Safari

## 0.9.0

- YouTube no notch: mini player que continua do mesmo segundo da aba e volta para ela no mesmo ponto
- Aba Bluetooth com a bateria dos dispositivos, bateria dos fones no topo do notch e avisos de conexão e bateria baixa

## 0.8.2

- Área de teste no formato de touchpad para vibração e gestos
- Lógica de gestos compartilhada entre o notch e a área de teste

## 0.8.1

- Intensidade da vibração configurável e separada do som

## 0.8.0

- Direção da troca de música configurável (direita = próxima por padrão)
- Dois dedos para cima e para baixo controlam o volume, com barra no notch

## 0.7.2

- Agenda mostra "amanhã" ou o dia da semana corretamente

## 0.7.1

- Vibração pelo motor do trackpad, funcionando com o app em segundo plano

## 0.7.0

- Tela de ajustes
- Gestos no trackpad
- Agenda com botão Entrar e contagem regressiva para reuniões
- Contador do WhatsApp

## 0.6.0

- Animação ao desligar no estilo de TV antiga (mais lenta na 0.6.1)

## 0.5.0

- Contador animado de notificações do ClickUp

## 0.4.0

- Clima com previsão das próximas horas
- Histórico de copiados

## 0.3.0

- Ícone novo
- Notch recolhido sem contagem de sessões e com o tempo da tarefa
- Ir para o terminal mais robusto

## 0.2.0

- Aprovar permissões do Claude Code pelo notch
- Clicar numa sessão leva à aba certa do terminal
- Cota de uso de 5 horas e 7 dias
- Som e vibração nos avisos
- Barra de progresso arrastável e cor da capa no fundo
- Ícone e instalador

## 0.1.0

- Primeira versão: música do Spotify e do Music e sessões do Claude Code no notch

## Instalador

Ao longo das versões, o `install.sh` ganhou barra de progresso, atualização só do que mudou, assinatura com certificado local estável e limpeza das permissões antigas da época da assinatura ad-hoc.
