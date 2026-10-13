#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")" || exit 1

FORCE=0
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE=1 ;;
        --uninstall) exec bash bin/notchy uninstall ;;
    esac
done

BUNDLE_ID="io.github.lleonardo-franco.notchy"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist 2>/dev/null || echo '')"
STAGE="build/Notchy.app"
TARGET="/Applications/Notchy.app"
LOG="${TMPDIR:-/tmp}/notchy-install.log"
: > "$LOG"

IDENTITY="Notchy Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
STATE_DIR="$HOME/Library/Application Support/Notchy"
KEYCHAIN_MARK="$STATE_DIR/keychain-ready"
PERMISSIONS_MARK="$STATE_DIR/permissions-reset-for-certificate"
PERMISSIONS_RESET=0
TRUST_MARK="$STATE_DIR/trust-attempted"

TITLES=("Preparando a assinatura" "Compilando o Notchy" "Montando o app" "Instalando em /Applications" "Conectando ao Claude Code" "Instalando o comando notchy" "Abrindo o Notchy")
DETAILS=("certificado local" "preparando o Swift…" "ícone, Info.plist e assinatura" "fechando a versão antiga" "hooks, aprovações e status line" "notchy · notchy stop · notchy restart" "procurando o notch…")
WEIGHTS=(4 58 8 8 10 6 6)
BUILD_STEP=1
TOTAL=${#TITLES[@]}
SPIN=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

DONE_WEIGHT=0
DRAWN=0
JOB=""
SUB=0
DETAIL=""
BAR=""

if [ -t 1 ]; then FANCY=1; else FANCY=0; fi
COLS=$(tput cols 2>/dev/null || echo 80)
[ "$COLS" -gt 0 ] 2>/dev/null || COLS=80
BAR_WIDTH=28
[ "$COLS" -lt 72 ] && BAR_WIDTH=16

if [ $FANCY -eq 1 ]; then
    R=$'\033[0m'
    B=$'\033[1m'
    DIM=$'\033[38;2;125;125;138m'
    FAINT=$'\033[38;2;60;60;70m'
    ORANGE=$'\033[38;2;217;119;87m'
    GREEN=$'\033[38;2;110;210;140m'
    RED=$'\033[38;2;240;95;95m'
    YELLOW=$'\033[38;2;240;200;90m'
else
    R="" B="" DIM="" FAINT="" ORANGE="" GREEN="" RED="" YELLOW=""
fi

rgb() {
    [ $FANCY -eq 1 ] && printf '\033[38;2;%d;%d;%dm' "$1" "$2" "$3"
}

lerp() {
    echo $(( $1 + ($2 - $1) * $3 / 1000 ))
}

fmt_time() {
    local s=$1
    if [ "$s" -lt 60 ]; then
        printf '%ds' "$s"
    else
        printf '%dm%02ds' $((s / 60)) $((s % 60))
    fi
}

make_bar() {
    local pct=$1 width=$2 filled i t seg out=""
    filled=$(( pct * width / 100 ))
    for (( i = 0; i < width; i++ )); do
        if [ $i -lt $filled ]; then
            t=$(( i * 1000 / (width > 1 ? width - 1 : 1) ))
            if [ $FANCY -eq 1 ]; then
                printf -v seg '\033[38;2;%d;%d;%dm━' $(( 150 + (217 - 150) * t / 1000 )) $(( 100 + (119 - 100) * t / 1000 )) $(( 240 + (87 - 240) * t / 1000 ))
                out+=$seg
            else
                out+="#"
            fi
        else
            if [ $FANCY -eq 1 ]; then out+="${FAINT}━"; else out+="-"; fi
        fi
    done
    BAR="${out}${R}"
}

draw() {
    if [ $DRAWN -eq 1 ]; then
        printf '\r\033[2K\033[1A\r\033[2K'
    fi
    printf '%s\n\033[2K%s' "$1" "$2"
    DRAWN=1
}

commit() {
    if [ $DRAWN -eq 1 ]; then
        printf '\r\033[2K\033[1A\r\033[2K'
        DRAWN=0
    fi
    printf '%s\n' "$1"
}

cleanup() {
    [ $FANCY -eq 1 ] && printf '\033[?25h'
}

interrupt() {
    [ -n "$JOB" ] && kill "$JOB" 2>/dev/null
    commit ""
    commit "  ${YELLOW}Instalação cancelada.${R}"
    exit 130
}

trap cleanup EXIT
trap interrupt INT TERM

banner() {
    local lines=(
        "███╗   ██╗  ██████╗  ████████╗  ██████╗ ██╗  ██╗ ██╗   ██╗"
        "████╗  ██║ ██╔═══██╗ ╚══██╔══╝ ██╔════╝ ██║  ██║ ╚██╗ ██╔╝"
        "██╔██╗ ██║ ██║   ██║    ██║    ██║      ███████║  ╚████╔╝ "
        "██║╚██╗██║ ██║   ██║    ██║    ██║      ██╔══██║   ╚██╔╝  "
        "██║ ╚████║ ╚██████╔╝    ██║    ╚██████╗ ██║  ██║    ██║   "
        "╚═╝  ╚═══╝  ╚═════╝     ╚═╝     ╚═════╝ ╚═╝  ╚═╝    ╚═╝   "
    )
    echo
    if [ "$COLS" -ge 64 ]; then
        local i t
        for i in 0 1 2 3 4 5; do
            t=$(( i * 200 ))
            printf '  %s%s%s\n' "$(rgb "$(lerp 150 217 $t)" "$(lerp 100 119 $t)" "$(lerp 240 87 $t)")" "${lines[$i]}" "$R"
        done
    else
        printf '  %s%sN O T C H Y%s\n' "$B" "$ORANGE" "$R"
    fi
    echo
    printf '  %sseu notch, menos inútil%s  %s·  música + Claude Code%s  %s%s%s\n\n' "$B" "$R" "$DIM" "$R" "$FAINT" "${VERSION:+v$VERSION}" "$R"
}

need() {
    printf '  %s✗%s %s\n' "$RED" "$R" "$1"
    printf '    %s%s%s\n\n' "$DIM" "$2" "$R"
    exit 1
}

preflight() {
    [ "$(uname)" = "Darwin" ] || need "O Notchy só roda no macOS." "Rode este instalador num Mac."
    command -v swift >/dev/null || need "Swift não encontrado." "Instale as ferramentas de linha de comando: xcode-select --install"
    command -v iconutil >/dev/null || need "iconutil não encontrado." "Instale as ferramentas de linha de comando: xcode-select --install"
    command -v python3 >/dev/null || need "Python 3 não encontrado." "Instale as ferramentas de linha de comando: xcode-select --install"
    [ -w /Applications ] || need "Sem permissão para escrever em /Applications." "Use uma conta de administrador."
}

build_progress() {
    local last re='^\[([0-9]+)/([0-9]+)\] (.*)$'
    last=$(grep -E '^\[[0-9]+/[0-9]+\]' "$LOG" 2>/dev/null | tail -n 1)
    if [[ $last =~ $re ]]; then
        local n=${BASH_REMATCH[1]} m=${BASH_REMATCH[2]} what=${BASH_REMATCH[3]}
        [ "$m" -gt 0 ] && SUB=$(( n * 100 / m ))
        [ $SUB -gt 99 ] && SUB=99
        what=${what/Compiling Notchy /compilando }
        what=${what/Compiling /compilando }
        what=${what/Linking /linkando }
        what=${what/Emitting module /gerando o módulo }
        what=${what/Write /gravando }
        what=${what/Planning build/planejando}
        DETAIL="$what"
    fi
}

render() {
    local index=$1 frame=$2 counter overall max detail line1 line2
    overall=$(( DONE_WEIGHT + WEIGHTS[index] * SUB / 100 ))
    make_bar "$overall" "$BAR_WIDTH"
    counter="$((index + 1))/$TOTAL"
    printf -v line1 '  %s%s%s %s%-32s%s %s%s%s' "$ORANGE" "${SPIN[$frame]}" "$R" "$B" "${TITLES[$index]}" "$R" "$DIM" "$counter" "$R"
    max=$(( COLS - BAR_WIDTH - 14 ))
    [ $max -lt 0 ] && max=0
    detail="$DETAIL"
    [ ${#detail} -gt $max ] && detail="${detail:0:$((max > 1 ? max - 1 : 0))}…"
    printf -v line2 '    %s %s%3d%%%s  %s%s%s' "$BAR" "$B" "$overall" "$R" "$DIM" "$detail" "$R"
    draw "$line1" "$line2"
}

run() {
    local index=$1
    shift
    local start frame=0 code elapsed
    start=$(date +%s)
    SUB=0
    DETAIL="${DETAILS[$index]}"
    printf '\n### %s\n' "${TITLES[$index]}" >>"$LOG"

    [ $FANCY -eq 0 ] && printf '[%d/%d] %s… ' $((index + 1)) "$TOTAL" "${TITLES[$index]}"

    "$@" >>"$LOG" 2>&1 &
    JOB=$!
    while kill -0 "$JOB" 2>/dev/null; do
        if [ $FANCY -eq 1 ]; then
            [ "$index" -eq "$BUILD_STEP" ] && build_progress
            render "$index" "$frame"
            frame=$(( (frame + 1) % ${#SPIN[@]} ))
        fi
        sleep 0.08
    done
    wait "$JOB"
    code=$?
    JOB=""
    elapsed=$(( $(date +%s) - start ))

    if [ $code -eq 0 ]; then
        DONE_WEIGHT=$(( DONE_WEIGHT + WEIGHTS[index] ))
        if [ $FANCY -eq 1 ]; then
            local line
            printf -v line '  %s✓%s %-32s %s%s%s' "$GREEN" "$R" "${TITLES[$index]}" "$DIM" "$(fmt_time $elapsed)" "$R"
            commit "$line"
        else
            echo "ok ($(fmt_time $elapsed))"
        fi
    else
        if [ $FANCY -eq 1 ]; then
            commit "  ${RED}✗ ${TITLES[$index]}${R}"
        else
            echo "falhou"
        fi
        fail
    fi
}

skip() {
    local index=$1 reason=$2
    DONE_WEIGHT=$(( DONE_WEIGHT + WEIGHTS[index] ))
    printf '\n### %s (pulado: %s)\n' "${TITLES[$index]}" "$reason" >>"$LOG"
    if [ $FANCY -eq 1 ]; then
        local line
        printf -v line '  %s↷ %-32s %s%s' "$DIM" "${TITLES[$index]}" "$reason" "$R"
        commit "$line"
    else
        printf '[%d/%d] %s… pulado (%s)\n' $((index + 1)) "$TOTAL" "${TITLES[$index]}" "$reason"
    fi
}

fingerprint() {
    {
        find Sources Resources hooks scripts Package.swift -type f ! -name '.DS_Store' ! -name '*.pyc' -print0 | sort -z | xargs -0 shasum -a 256
        if has_identity; then echo "signed:$IDENTITY"; else echo "signed:adhoc"; fi
    } | shasum -a 256 | cut -d' ' -f1
}

hooks_fingerprint() {
    cat hooks/*.py | shasum -a 256 | cut -d' ' -f1
}

hooks_current() {
    [ "$(hooks_fingerprint)" = "$(cat "$HOME/.notchy/hooks.fingerprint" 2>/dev/null)" ] \
        && grep -qs "notchy-hook.py" "$HOME/.claude/settings.json" \
        && grep -qs "notchy-statusline.py" "$HOME/.claude/settings.json"
}

fail() {
    echo
    printf '  %s%sAlgo deu errado.%s\n\n' "$B" "$RED" "$R"
    if grep -q 'error:' "$LOG"; then
        grep 'error:' "$LOG" | head -n 12 | while IFS= read -r line; do
            printf '    %s%s%s\n' "$DIM" "$line" "$R"
        done
    else
        tail -n 15 "$LOG" | while IFS= read -r line; do
            printf '    %s%s%s\n' "$DIM" "$line" "$R"
        done
    fi
    printf '\n  Log completo: %s\n\n' "$LOG"
    exit 1
}

step_build() {
    scripts/compile.sh
}

has_identity() {
    security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""
}

step_identity() {
    has_identity && return 0
    local dir
    dir=$(mktemp -d)
    if ! security find-certificate -c "$IDENTITY" -p "$KEYCHAIN" > "$dir/cert.pem" 2>/dev/null || [ ! -s "$dir/cert.pem" ]; then
        cat > "$dir/cert.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF
        openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
            -keyout "$dir/key.pem" -out "$dir/cert.pem" -config "$dir/cert.cnf" || { rm -rf "$dir"; return 0; }
        openssl pkcs12 -export -inkey "$dir/key.pem" -in "$dir/cert.pem" -out "$dir/bundle.p12" \
            -passout pass:notchy -name "$IDENTITY" \
            -macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES || { rm -rf "$dir"; return 0; }
        security import "$dir/bundle.p12" -k "$KEYCHAIN" -P notchy -T /usr/bin/codesign -T /usr/bin/security || { rm -rf "$dir"; return 0; }
    fi
    security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$dir/cert.pem" || true
    rm -rf "$dir"
    return 0
}

prepare_signing() {
    mkdir -p "$STATE_DIR"
    if ! has_identity; then
        if [ -f "$TRUST_MARK" ] && [ $FORCE -eq 0 ]; then
            return 0
        fi
        printf '  %s✱%s %sCriando o certificado local do Notchy%s %s(só desta vez)%s\n' "$ORANGE" "$R" "$B" "$R" "$DIM" "$R"
        printf '    %sO macOS vai abrir uma janela pedindo sua senha para confiar nele.%s\n' "$DIM" "$R"
        step_identity >>"$LOG" 2>&1
        touch "$TRUST_MARK"
        rm -f "$KEYCHAIN_MARK"
        if has_identity; then
            printf '    %s✓ certificado pronto%s\n\n' "$GREEN" "$R"
        else
            printf '    %s✗ não deu para confiar no certificado, vou usar assinatura ad-hoc%s\n\n' "$YELLOW" "$R"
            return 0
        fi
    fi
    if [ ! -f "$KEYCHAIN_MARK" ]; then
        printf '  %s✱%s %sLiberando o certificado para o codesign%s %s(só desta vez)%s\n' "$ORANGE" "$R" "$B" "$R" "$DIM" "$R"
        printf '    %sDigite a senha do seu Mac. Depois disso, as atualizações não pedem mais senha.%s\n' "$DIM" "$R"
        [ $FANCY -eq 1 ] && printf '\033[?25h'
        if security set-key-partition-list -S apple-tool:,apple:,codesign: -s -l "$IDENTITY" "$KEYCHAIN" >>"$LOG" </dev/tty; then
            touch "$KEYCHAIN_MARK"
            printf '    %s✓ liberado%s\n\n' "$GREEN" "$R"
        else
            printf '    %s✗ não liberou; o macOS pode pedir a senha ao assinar. Rode ./install.sh --force para tentar de novo.%s\n\n' "$YELLOW" "$R"
        fi
        [ $FANCY -eq 1 ] && printf '\033[?25l'
    fi
}

installed_signature() {
    local info
    info=$(codesign -dvv "$TARGET" 2>&1)
    if grep -q "Authority=$IDENTITY" <<<"$info"; then
        echo "stable"
    elif grep -q "Signature=adhoc" <<<"$info"; then
        echo "adhoc"
    else
        echo "unknown"
    fi
}

step_bundle() {
    NOTCHY_FINGERPRINT="$FINGERPRINT" scripts/bundle.sh "$STAGE"
}

step_applications() {
    if pgrep -x Notchy >/dev/null; then
        osascript -e "tell application id \"$BUNDLE_ID\" to quit" || true
        local i
        for (( i = 0; i < 30; i++ )); do
            pgrep -x Notchy >/dev/null || break
            sleep 0.2
        done
        pkill -x Notchy || true
    fi
    rm -rf "$TARGET" || return 1
    cp -R "$STAGE" "$TARGET" || return 1
    touch "$TARGET"
}

step_hooks() {
    python3 hooks/install.py || return 1
    hooks_fingerprint > "$HOME/.notchy/hooks.fingerprint"
}

step_cli() {
    mkdir -p "$BIN_DIR" || return 1
    install -m 755 bin/notchy "$BIN_DIR/notchy" || return 1
    if [ "$NEED_PATH" -eq 1 ]; then
        printf '\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$HOME/.zshrc"
    fi
}

step_open() {
    open "$TARGET" || return 1
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x Notchy >/dev/null && return 0
        sleep 0.3
    done
    return 1
}

BIN_DIR="$HOME/.local/bin"
if [ -d /opt/homebrew/bin ] && [ -w /opt/homebrew/bin ]; then
    BIN_DIR="/opt/homebrew/bin"
elif [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    BIN_DIR="/usr/local/bin"
fi
NEED_PATH=0
if [ "${NOTCHY_HOMEBREW:-0}" != "1" ] && [[ ":$PATH:" != *":$BIN_DIR:"* ]] && ! grep -qs "$BIN_DIR" "$HOME/.zshrc"; then
    NEED_PATH=1
fi

INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TARGET/Contents/Info.plist" 2>/dev/null || echo '')"
INSTALLED_FINGERPRINT="$(cat "$TARGET/Contents/Resources/build.fingerprint" 2>/dev/null || echo '')"

[ $FANCY -eq 1 ] && printf '\033[?25l'
banner
preflight

if [ $FORCE -eq 1 ]; then
    printf '  %sreinstalando tudo (--force)%s\n\n' "$YELLOW" "$R"
elif [ -n "$INSTALLED_VERSION" ]; then
    if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
        printf '  %sinstalada%s v%s  %s· conferindo o que mudou%s\n\n' "$DIM" "$R" "$INSTALLED_VERSION" "$DIM" "$R"
    else
        printf '  %sinstalada%s v%s  %s→%s  %snova%s %sv%s%s\n\n' "$DIM" "$R" "$INSTALLED_VERSION" "$ORANGE" "$R" "$DIM" "$R" "$B" "$VERSION" "$R"
    fi
else
    printf '  %sprimeira instalação%s\n\n' "$DIM" "$R"
fi

mkdir -p "$STATE_DIR"
echo "${NOTCHY_SOURCE:-$(pwd)}" > "$STATE_DIR/source"

STARTED=$(date +%s)
CHANGED=0
if [ $FORCE -eq 1 ]; then
    rm -f "$KEYCHAIN_MARK"
fi
prepare_signing
if has_identity; then
    skip 0 "certificado pronto"
else
    skip 0 "usando assinatura ad-hoc"
fi
FINGERPRINT="$(fingerprint)"

if [ $FORCE -eq 0 ] && [ -d "$TARGET" ] && [ "$FINGERPRINT" = "$INSTALLED_FINGERPRINT" ]; then
    APP_CHANGED=0
    skip 1 "sem mudanças no código"
    skip 2 "nada para montar"
    skip 3 "v$INSTALLED_VERSION já instalada"
else
    APP_CHANGED=1
    CHANGED=1
    run 1 step_build
    run 2 step_bundle
    run 3 step_applications
fi

if [ $FORCE -eq 0 ] && hooks_current; then
    skip 4 "já conectado"
else
    CHANGED=1
    run 4 step_hooks
fi

if [ "${NOTCHY_HOMEBREW:-0}" = "1" ]; then
    skip 5 "gerenciado pelo Homebrew"
elif [ $FORCE -eq 0 ] && cmp -s bin/notchy "$BIN_DIR/notchy"; then
    skip 5 "já instalado"
else
    CHANGED=1
    run 5 step_cli
fi

if [ "$(installed_signature)" = "stable" ] && [ ! -f "$PERMISSIONS_MARK" ]; then
    if pgrep -x Notchy >/dev/null; then
        osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
        for (( i = 0; i < 30; i++ )); do
            pgrep -x Notchy >/dev/null || break
            sleep 0.2
        done
        pkill -x Notchy >/dev/null 2>&1 || true
    fi
    for service in Accessibility AppleEvents Calendar BluetoothAlways; do
        tccutil reset "$service" "$BUNDLE_ID" >>"$LOG" 2>&1 || true
    done
    BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$TARGET/Contents/Info.plist" 2>/dev/null || echo '')"
    defaults delete "$BUNDLE_ID" "accessibilityPrompted-$BUILD_NUMBER" >/dev/null 2>&1 || true
    mkdir -p "$STATE_DIR"
    touch "$PERMISSIONS_MARK"
    PERMISSIONS_RESET=1
    CHANGED=1
fi

if [ $APP_CHANGED -eq 0 ] && pgrep -x Notchy >/dev/null; then
    skip 6 "já está aberto"
else
    run 6 step_open
fi
TOOK=$(( $(date +%s) - STARTED ))

echo
make_bar 100 "$BAR_WIDTH"
printf '    %s %s100%%%s\n\n' "$BAR" "$B" "$R"
if [ $CHANGED -eq 0 ]; then
    printf '  %s✱%s %sNotchy já está atualizado%s %sv%s · nada para fazer%s\n\n' "$ORANGE" "$R" "$B" "$R" "$DIM" "$VERSION" "$R"
elif [ -z "$INSTALLED_VERSION" ]; then
    printf '  %s✱%s %sNotchy v%s instalado%s %sem %s%s\n\n' "$ORANGE" "$R" "$B" "$VERSION" "$R" "$DIM" "$(fmt_time $TOOK)" "$R"
elif [ $APP_CHANGED -eq 1 ]; then
    printf '  %s✱%s %sNotchy atualizado para v%s%s %sem %s%s\n\n' "$ORANGE" "$R" "$B" "$VERSION" "$R" "$DIM" "$(fmt_time $TOOK)" "$R"
else
    printf '  %s✱%s %sNotchy v%s · ajustes atualizados%s %sem %s%s\n\n' "$ORANGE" "$R" "$B" "$VERSION" "$R" "$DIM" "$(fmt_time $TOOK)" "$R"
fi
printf '    %s%-10s%s %s\n' "$DIM" "App" "$R" "$TARGET"
printf '    %s%-10s%s notchy %s·%s settings %s·%s doctor %s·%s update %s·%s uninstall\n' "$DIM" "Comando" "$R" "$DIM" "$R" "$DIM" "$R" "$DIM" "$R" "$DIM" "$R"
case "$(installed_signature)" in
    stable)
        printf '    %s%-10s%s %s %s✓ estável, as permissões ficam salvas entre versões%s\n' "$DIM" "Assinatura" "$R" "$IDENTITY" "$GREEN" "$R"
        ;;
    adhoc)
        printf '    %s%-10s%s ad-hoc %s✗ o macOS vai pedir as permissões a cada atualização · rode notchy doctor%s\n' "$DIM" "Assinatura" "$R" "$YELLOW" "$R"
        ;;
    *)
        printf '    %s%-10s%s %snão consegui conferir · rode notchy doctor%s\n' "$DIM" "Assinatura" "$R" "$YELLOW" "$R"
        ;;
esac
printf '    %s%-10s%s %s\n\n' "$DIM" "Log" "$R" "$LOG"
if [ $PERMISSIONS_RESET -eq 1 ]; then
    printf '  %s✱ Limpei as permissões antigas, que eram da assinatura ad-hoc.%s\n' "$ORANGE" "$R"
    printf '  %s  Autorize uma última vez o que o macOS pedir (Acessibilidade, navegador, Calendário).%s\n' "$DIM" "$R"
    printf '  %s  Daqui pra frente, as atualizações não pedem mais.%s\n\n' "$DIM" "$R"
fi
if [ $CHANGED -eq 1 ]; then
    printf '  Passe o mouse no notch pra começar.\n'
    printf '  %sReinicie as sessões do Claude Code que já estavam abertas.%s\n' "$DIM" "$R"
fi
printf '  %sPara reinstalar tudo do zero: ./install.sh --force%s\n' "$DIM" "$R"
if [ "$NEED_PATH" -eq 1 ]; then
    printf '  %sAbra um terminal novo para usar o comando notchy.%s\n' "$DIM" "$R"
fi
echo
