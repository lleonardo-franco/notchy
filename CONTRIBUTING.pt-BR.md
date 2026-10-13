# Contribuindo com o Notchy

[English](CONTRIBUTING.md) · **Português** · [Español](CONTRIBUTING.es.md)

Valeu por querer ajudar! O Notchy é um projeto pequeno e toda contribuição conta, de um erro de digitação a uma aba nova inteira. Este guia explica como propor mudanças por meio de um **fork e um pull request**.

## Sumário

- [Formas de contribuir](#formas-de-contribuir)
- [Antes de começar](#antes-de-começar)
- [Fork, branch, pull request](#fork-branch-pull-request)
- [Mantendo seu fork atualizado](#mantendo-seu-fork-atualizado)
- [Preparando o ambiente](#preparando-o-ambiente)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Estilo de código](#estilo-de-código)
- [Mensagens de commit](#mensagens-de-commit)
- [Testes](#testes)
- [Documentação e traduções](#documentação-e-traduções)
- [Revisão e merge](#revisão-e-merge)

## Formas de contribuir

| | Como |
|---|---|
| 🐞 Relatar um bug | Use **Ajustes → Sobre → Relatar problema…**, que preenche o relato com o diagnóstico, ou [abra um](https://github.com/lleonardo-franco/notchy/issues/new?template=bug_report.yml) com a saída do `notchy doctor` |
| 💡 Sugerir uma funcionalidade | [Abra uma sugestão](https://github.com/lleonardo-franco/notchy/issues/new?template=feature_request.yml) descrevendo o problema que ela resolve |
| 🌍 Traduzir | Traduza a documentação ou ajude a levar a interface para mais idiomas |
| 📝 Melhorar a documentação | Corrija o que estiver confuso, desatualizado ou faltando |
| 🛠️ Programar | Pegue uma issue, principalmente as com a etiqueta [`good first issue`](https://github.com/lleonardo-franco/notchy/labels/good%20first%20issue) ou [`help wanted`](https://github.com/lleonardo-franco/notchy/labels/help%20wanted) |

Issues e pull requests em português, inglês ou espanhol são todos bem-vindos.

## Antes de começar

- **Pesquise antes.** Alguém pode já ter relatado o bug ou sugerido a ideia.
- **Abra uma issue antes de mudanças grandes.** Para qualquer coisa além de uma correção pequena, descreva o que pretende fazer e espere um ok. Isso evita que você construa algo que não vai entrar.
- **Avise que vai pegar a issue.** Comente nela para os outros saberem que você está trabalhando nisso.
- **Problemas de segurança** nunca vão em issues públicas. Siga o [SECURITY.md](SECURITY.md).

## Fork, branch, pull request

Você não precisa de acesso de escrita ao repositório. Toda mudança entra por pull request a partir do seu próprio fork.

**1. Faça o fork** do repositório pelo botão **Fork** no topo da [página do repo](https://github.com/lleonardo-franco/notchy). Isso cria `github.com/<seu-usuario>/notchy`.

**2. Clone o seu fork** e adicione o repositório original como `upstream`:

```bash
git clone https://github.com/<seu-usuario>/notchy.git
cd notchy
git remote add upstream https://github.com/lleonardo-franco/notchy.git
```

**3. Crie uma branch** a partir da `main` mais recente. Nunca trabalhe direto na `main`.

```bash
git fetch upstream
git switch -c feat/descricao-curta upstream/main
```

| Prefixo | Para |
|---|---|
| `feat/` | Funcionalidades novas |
| `fix/` | Correções de bugs |
| `docs/` | Documentação |
| `i18n/` | Traduções |
| `refactor/` | Mudanças no código que não alteram o comportamento |
| `chore/` | Build, CI, ferramentas |

**4. Faça as mudanças**, depois compile e teste (veja [Preparando o ambiente](#preparando-o-ambiente) e [Testes](#testes)).

**5. Faça o commit** seguindo as [Mensagens de commit](#mensagens-de-commit) e **envie para o seu fork**:

```bash
git push -u origin feat/descricao-curta
```

**6. Abra o pull request.** O GitHub mostra um botão **Compare & pull request** no seu fork. Confira se a base é `lleonardo-franco/notchy` → `main`, preencha o modelo e vincule a issue com `Closes #123`. Deixe marcado **Allow edits by maintainers** para que correções pequenas possam ser feitas direto na sua branch.

**7. Acompanhe a revisão.** Envie novos commits para a mesma branch para responder aos comentários. O pull request se atualiza sozinho.

## Mantendo seu fork atualizado

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
```

Para atualizar a branch em que você está trabalhando:

```bash
git switch feat/descricao-curta
git rebase upstream/main
git push --force-with-lease
```

## Preparando o ambiente

**Requisitos:** macOS 14 ou mais novo, Xcode 16 ou as ferramentas de linha de comando dele (`xcode-select --install`), Python 3.

```bash
swift build              # checagem rápida de compilação
swift test               # testes unitários (precisa do Xcode 16)
./build.sh               # gera build/Notchy.app
./install.sh             # instala em /Applications, refazendo só o que mudou
./install.sh --force     # reinstalação completa
```

Use o `./install.sh` para testar suas mudanças. Ele assina o app com o seu certificado local **Notchy Local Signing**, então o macOS mantém as permissões entre as compilações. Rodar o `build/Notchy.app` com assinatura ad-hoc funciona, mas o macOS vai pedir as permissões de novo a cada vez.

Úteis para depurar:

| | |
|---|---|
| `notchy doctor` | Assinatura, certificado, permissões e se o app está rodando |
| `notchy restart` | Reinicia depois de instalar |
| `~/.notchy/sessions/` | Um JSON por sessão do Claude Code, gravado pelos hooks |
| `~/.notchy/approvals/` | Pedidos de permissão pendentes e as respostas |
| `~/Library/Application Support/Notchy/status.json` | Estado das permissões gravado pelo app |

## Estrutura do projeto

| Caminho | O que tem lá |
|---|---|
| `Sources/Notchy/AppDelegate.swift` | Janela do painel, rastreio do mouse, gestos, telas e tela cheia |
| `Sources/Notchy/NotchModel.swift` | Estado do app: modos, abas, tamanhos e ligação entre os serviços |
| `Sources/Notchy/*Service.swift` | Um serviço por integração: música, Claude, agenda, clima, copiados, notificações, Bluetooth, mídia do navegador |
| `Sources/Notchy/*Views.swift`, `NotchView.swift` | Views SwiftUI |
| `Sources/Notchy/Preferences.swift`, `SettingsView.swift` | Ajustes e a janela de ajustes |
| `Sources/Notchy/PermissionCenter.swift`, `WelcomeView.swift` | Verificação de permissões e boas-vindas |
| `hooks/` | Hooks do Claude Code, wrapper da status line e o instalador deles |
| `bin/notchy` | Ferramenta de linha de comando |
| `install.sh`, `build.sh` | Instalador e script de build |
| `Resources/` | `Info.plist` e o ícone do app |

## Estilo de código

- **Swift e SwiftUI.** Os modelos usam `@Observable`; o código de interface roda no main actor. Os serviços cuidam dos efeitos colaterais; as views ficam enxutas.
- **Sem comentários no código.** Prefira nomes claros e funções pequenas que se explicam sozinhas.
- **Siga os padrões ao redor.** Use a mesma nomenclatura, organização e formatação do código que você está editando.
- **Dê nome ao que você adicionar.** Botões só com ícone precisam de `help:` (ele também vira o rótulo do VoiceOver); controles próprios precisam de `accessibilityLabel` e, quando mostram um valor, `accessibilityValue`.
- **Nunca trave a thread principal.** Rode AppleScript pelo `AppleScript.run`, que tem tempo limite.
- **Respeite o modo de repouso e o bloqueio.** Timers e verificações periódicas não devem rodar enquanto `SystemActivity.shared.paused` for verdadeiro.
- **Permissão nova?** Adicione no `PermissionCenter`, na janela de boas-vindas, no texto de uso do `Info.plist` e na tabela de permissões de todos os READMEs.
- **Hooks** usam só a biblioteca padrão do Python e precisam rodar no `/usr/bin/python3` do sistema.
- **Scripts de shell** precisam funcionar com o bash 3.2 que vem no macOS.
- **Textos da interface** são escritos em português do Brasil no código e traduzidos pelo `i18n/translations.py`. Use `Text("…")` para textos fixos e `String(localized: "…")` para textos montados no código, e depois adicione as versões em inglês e espanhol (veja [Documentação e traduções](#documentação-e-traduções)).

## Mensagens de commit

Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/), em inglês:

```
feat(video): add playback speed control
fix(calendar): show weekday for events after tomorrow
docs: explain how to enable JavaScript from Apple Events
i18n(es): translate the contributing guide
```

Mantenha cada commit focado em uma mudança. Um corpo curto explicando o *porquê* é sempre bem-vindo.

## Testes

Os testes unitários ficam em `Tests/NotchyTests` e usam [Swift Testing](https://developer.apple.com/xcode/swift-testing/). Rode com `swift test`; eles precisam do Xcode 16, porque só as ferramentas de linha de comando podem não trazer os frameworks de teste. Lógica pura (rótulos de data, gestos, parsing) deve vir com testes.

Não há testes automatizados de interface, então o teste manual continua importando:

1. Rode o `./install.sh` e experimente o que você mudou.
2. Passe pelas seções relacionadas do [roteiro de teste](TESTING.md).
3. Escreva no pull request o que testou e em qual Mac e versão do macOS.

Todo pull request é compilado pelo [GitHub Actions](https://github.com/lleonardo-franco/notchy/actions) no macOS. O build precisa passar antes do merge.

## Documentação e traduções

O README e este guia existem em inglês, português e espanhol.

- Se mudar um deles, atualize os outros também. Se não conseguir, avise no pull request que alguém ajuda.
- Para adicionar um idioma, crie `README.<código>.md` e `CONTRIBUTING.<código>.md` (por exemplo `README.fr.md`) e adicione o link no topo de todas as versões.
- A interface do app é traduzida no `i18n/translations.py`, com o texto em português como chave, `%@` para texto e `%lld` para números inteiros. Depois de editar, rode `python3 i18n/generate.py` para gerar os arquivos `.strings` em `Resources/`, e `python3 i18n/check.py` para listar textos do código que ainda não têm tradução.
- Para adicionar um idioma ao app, adicione uma coluna no `translations.py`, ensine o `generate.py` sobre ela e coloque o código do idioma em `CFBundleLocalizations` no `Resources/Info.plist`.
- As capturas do README e o tour animado são desenhados pelas próprias views do app com dados de exemplo (`Sources/Notchy/Showcase.swift`). Se a sua mudança altera a aparência do notch ou dos ajustes, rode o workflow **Screenshots** na aba Actions, ou faça push de uma branch chamada `shots/<algo>` e ele commita as novas imagens nela. Localmente: `swift build`, `NOTCHY_CONFIGURATION=debug scripts/bundle.sh build/Showcase.app`, depois `NOTCHY_SHOWCASE=build/showcase/pt-BR build/Showcase.app/Contents/MacOS/Notchy -AppleLanguages '(pt-BR)'` para cada idioma e `python3 scripts/screenshots.py build/showcase docs/screenshots` (precisa do Pillow).

Adicione uma linha descrevendo sua mudança em **Unreleased** no [CHANGELOG.md](CHANGELOG.md).

## Revisão e merge

- Um mantenedor revisa os pull requests, normalmente em poucos dias.
- Podem ser pedidas mudanças; isso faz parte do processo.
- Os pull requests entram com squash merge, então o título vira a mensagem do commit. Escreva-o como um Conventional Commit.

Ao contribuir, você concorda que seu trabalho fica sob a [licença MIT](LICENSE) e que vai seguir o [Código de Conduta](CODE_OF_CONDUCT.md).
