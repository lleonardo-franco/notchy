# Roteiro de teste

Uma passada por tudo antes de publicar uma versão. Marque cada item; se algo falhar, rode `notchy doctor` e anote a saída.

## Instalação

- [ ] `./install.sh --force` termina sem erro e sem warnings no log (`grep -i warning` no caminho do log)
- [ ] O resumo mostra **Assinatura: Notchy Local Signing ✓ estável**
- [ ] Rodar `./install.sh` de novo pula tudo e mostra "já está atualizado"
- [ ] Mudar um arquivo Swift e rodar de novo recompila e reinstala sem pedir permissões
- [ ] `notchy doctor` mostra assinatura estável, certificado válido e as permissões dadas

## Boas-vindas e ajustes

- [ ] As boas-vindas abrem na primeira vez e cada botão "Permitir" leva ao pedido certo
- [ ] Cada linha vira "Pronto" depois de liberar
- [ ] `notchy settings`, a engrenagem no notch e abrir o app pelo Spotlight abrem os ajustes
- [ ] Desligar uma aba nos ajustes tira ela do notch

## Notch

- [ ] Passar o mouse abre; tirar o mouse fecha
- [ ] Com "Ao clicar", só abre clicando
- [ ] Com um app em tela cheia, o notch some e volta ao sair
- [ ] Ligar um monitor externo e trocar "Onde mostrar" reposiciona o notch
- [ ] Bloquear a tela e desbloquear: tudo volta a atualizar

## Música e gestos

- [ ] Spotify e Music mostram capa, título e controles
- [ ] Arrastar a barra pula o trecho
- [ ] Dois dedos para a direita: próxima música; esquerda: anterior (e o contrário com a opção invertida)
- [ ] Dois dedos para cima e para baixo mudam o volume, com a barra aparecendo
- [ ] A vibração muda com a intensidade escolhida; a área de teste responde a clique e gestos

## Claude Code

- [ ] Uma sessão nova aparece na aba Claude com o que está fazendo
- [ ] Pedido de permissão aparece no notch; Permitir, Negar e Responder no terminal funcionam
- [ ] Clicar na sessão leva à aba certa do Terminal ou do iTerm
- [ ] Os medidores de cota aparecem depois da primeira resposta

## Agenda, clima, copiados

- [ ] Eventos de hoje, de amanhã e de outros dias com o rótulo certo
- [ ] Botão Entrar abre a reunião; contagem regressiva no notch recolhido antes dela
- [ ] Clima mostra a cidade certa (ou a definida com `notchy city`)
- [ ] Copiar texto, imagem e arquivo aparece em Copiados; clicar copia de novo

## Notificações e Bluetooth

- [ ] Mensagem nova no WhatsApp e notificação no ClickUp animam o contador e mostram o aviso
- [ ] Conectar os fones mostra o aviso com a bateria; a aba Bluetooth lista os dispositivos

## Vídeo

- [ ] Com um vídeo no Safari: "Assistir no notch" pausa a aba e continua do mesmo segundo
- [ ] Voltar para a aba retoma no navegador no ponto certo
- [ ] O mesmo no Chrome
- [ ] Dois dedos para os lados no vídeo avançam e voltam 10 s
- [ ] Fechar o vídeo volta ao notch normal

## Fechar e desinstalar

- [ ] O botão de power e `notchy stop` mostram a animação de desligar
- [ ] `notchy uninstall` remove app, hooks e comando e devolve a status line antiga do Claude Code
