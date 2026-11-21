#!/usr/bin/env bash
# Estudio de Reels — instalador para macOS (sin sudo, sin Homebrew obligatorio).
#
# Instala en el usuario actual:
#   - uv (Python), ffmpeg/ffprobe, Node.js 22+
#   - la skill video-use (browser-use/video-use) con transcripción local Whisper
#   - las skills de HyperFrames (animaciones / motion graphics)
#   - las skills editar-reel y /editar de este paquete
#   - la carpeta del proyecto (por defecto ~/Reels) con su CLAUDE.md
#
# Es idempotente: se puede correr varias veces (sirve también para actualizar).
#
# Uso:
#   bash instalar.sh                 # proyecto en ~/Reels
#   bash instalar.sh "/ruta/a/Reels" # proyecto en otra carpeta
#   SKIP_MODEL=1 bash instalar.sh    # no descargar el modelo de Whisper ahora

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_SKILLS="$(cd "$HERE/../.." && pwd)"              # .../skills
TEMPLATES="$HERE/../templates"

REELS_DIR="${1:-$HOME/Reels}"
VU_DIR="${VIDEO_USE_DIR:-$HOME/Developer/video-use}"
# Versiones fijas, probadas con este paquete (se pueden sobreescribir con variables de entorno)
VU_REF="${VIDEO_USE_REF:-43cfc566833548093455c9d4a46bd69913b7e552}"
HF_VERSION="${HYPERFRAMES_VERSION:-0.9.63}"
LOCAL_BIN="$HOME/.local/bin"
NODE_HOME="$HOME/.local/share/estudio-reels/node"
SKILLS_DIR="$HOME/.claude/skills"

export PATH="$LOCAL_BIN:$HOME/.cargo/bin:$PATH"
mkdir -p "$LOCAL_BIN" "$SKILLS_DIR"

OK=(); WARN=(); FAIL=()
ok()   { echo "✅ $*"; OK+=("$*"); }
warn() { echo "⚠️  $*"; WARN+=("$*"); }
fail() { echo "❌ $*"; FAIL+=("$*"); }
step() { echo; echo "── $* ──"; }

# ----------------------------------------------------------------------------
step "0. Revisando la computadora"
if [ "$(uname -s)" != "Darwin" ]; then
  warn "Este instalador está hecho para Mac. Sistema detectado: $(uname -s). Sigo, pero algunos pasos pueden fallar."
fi
ARCH="$(uname -m)"
case "$ARCH" in
  arm64)  NODE_ARCH="arm64"; ok "Mac con chip Apple ($ARCH)";;
  x86_64) NODE_ARCH="x64";   warn "Mac con Intel: funciona, pero la transcripción será más lenta.";;
  *)      NODE_ARCH="$ARCH"; warn "Arquitectura no probada: $ARCH";;
esac

# Asegura ~/.local/bin en el PATH para futuras terminales
for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  if [ -f "$rc" ] || [ "$rc" = "$HOME/.zshrc" ]; then
    grep -qs 'estudio-reels PATH' "$rc" || \
      printf '\n# estudio-reels PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
  fi
done

# ----------------------------------------------------------------------------
step "1. uv (administrador de Python)"
if command -v uv >/dev/null 2>&1; then
  ok "uv ya estaba instalado ($(uv --version 2>/dev/null))"
else
  if curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 \
     && command -v uv >/dev/null 2>&1; then
    ok "uv instalado"
  else
    fail "No se pudo instalar uv"
  fi
fi

# ----------------------------------------------------------------------------
step "2. ffmpeg y ffprobe"
if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
  ok "ffmpeg ya estaba instalado"
elif command -v brew >/dev/null 2>&1 && brew install ffmpeg >/dev/null 2>&1; then
  ok "ffmpeg instalado con Homebrew"
elif command -v uv >/dev/null 2>&1; then
  PATHS="$(uv run --no-project --quiet --with static-ffmpeg python -c \
    'import static_ffmpeg.run as r; f,p=r.get_or_fetch_platform_executables_else_raise(); print(f); print(p)' 2>/dev/null)"
  FF="$(echo "$PATHS" | sed -n 1p)"; FP="$(echo "$PATHS" | sed -n 2p)"
  if [ -n "$FF" ] && [ -x "$FF" ] && [ -x "$FP" ]; then
    cp -f "$FF" "$LOCAL_BIN/ffmpeg" && cp -f "$FP" "$LOCAL_BIN/ffprobe"
    chmod +x "$LOCAL_BIN/ffmpeg" "$LOCAL_BIN/ffprobe"
    xattr -d com.apple.quarantine "$LOCAL_BIN/ffmpeg" "$LOCAL_BIN/ffprobe" 2>/dev/null || true
    ffmpeg -version >/dev/null 2>&1 && ok "ffmpeg instalado (binario estático en ~/.local/bin)" \
      || fail "ffmpeg se descargó pero no corre"
  else
    fail "No se pudo instalar ffmpeg"
  fi
else
  fail "No se pudo instalar ffmpeg (falta uv)"
fi

# ----------------------------------------------------------------------------
step "3. Node.js 22+ (para las animaciones)"
node_major() { node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }
if command -v node >/dev/null 2>&1 && [ "$(node_major)" -ge 22 ] 2>/dev/null; then
  ok "Node $(node -v) ya estaba instalado"
else
  BASE="https://nodejs.org/dist/latest-v22.x"
  TARBALL="$(curl -fsSL "$BASE/SHASUMS256.txt" 2>/dev/null | awk '{print $2}' \
             | grep -E "^node-v22\.[0-9.]+-darwin-${NODE_ARCH}\.tar\.gz$" | head -1)"
  if [ -n "$TARBALL" ]; then
    TMP="$(mktemp -d)"
    if curl -fsSL "$BASE/$TARBALL" -o "$TMP/node.tgz" && tar -xzf "$TMP/node.tgz" -C "$TMP"; then
      rm -rf "$NODE_HOME"; mkdir -p "$(dirname "$NODE_HOME")"
      mv "$TMP/${TARBALL%.tar.gz}" "$NODE_HOME"
      for b in node npm npx; do ln -sfn "$NODE_HOME/bin/$b" "$LOCAL_BIN/$b"; done
      ok "Node $(node -v) instalado en ~/.local"
    else
      fail "No se pudo descargar Node.js"
    fi
    rm -rf "$TMP"
  else
    fail "No se encontró la versión de Node.js para esta Mac"
  fi
fi

# ----------------------------------------------------------------------------
step "4. Skill video-use (cortes, subtítulos, render)"
VU_URL="https://github.com/browser-use/video-use"
git_ok() { command -v git >/dev/null 2>&1 && { [ "$(uname -s)" != "Darwin" ] || xcode-select -p >/dev/null 2>&1; }; }

if [ -d "$VU_DIR/.git" ] && git_ok; then
  git -C "$VU_DIR" checkout -- helpers/transcribe.py SKILL.md >/dev/null 2>&1
  if git -C "$VU_DIR" fetch --quiet origin >/dev/null 2>&1 && git -C "$VU_DIR" checkout --quiet "$VU_REF" >/dev/null 2>&1; then
    ok "video-use en la versión probada (${VU_REF:0:7})"
  else
    warn "No se pudo cambiar video-use a la versión probada (se usa la que ya estaba)"
  fi
elif [ ! -d "$VU_DIR" ] && git_ok; then
  mkdir -p "$(dirname "$VU_DIR")"
  if git clone --quiet "$VU_URL" "$VU_DIR" >/dev/null 2>&1 && git -C "$VU_DIR" checkout --quiet "$VU_REF" >/dev/null 2>&1; then
    ok "video-use descargado (${VU_REF:0:7})"
  else
    fail "No se pudo descargar video-use"
  fi
else
  # Sin git (o sin herramientas de Xcode): descarga directa
  TMP="$(mktemp -d)"
  if curl -fsSL "https://codeload.github.com/browser-use/video-use/tar.gz/$VU_REF" -o "$TMP/vu.tgz" \
     && tar -xzf "$TMP/vu.tgz" -C "$TMP"; then
    mkdir -p "$VU_DIR"
    cp -R "$TMP"/video-use-*/. "$VU_DIR"/
    ok "video-use descargado (${VU_REF:0:7})"
  else
    fail "No se pudo descargar video-use"
  fi
  rm -rf "$TMP"
fi

if [ -f "$VU_DIR/SKILL.md" ]; then
  # Entorno de Python + Whisper
  if command -v uv >/dev/null 2>&1; then
    [ -x "$VU_DIR/.venv/bin/python" ] || uv venv --quiet --python 3.12 "$VU_DIR/.venv" >/dev/null 2>&1
    if uv pip install --quiet --python "$VU_DIR/.venv/bin/python" -e "$VU_DIR" >/dev/null 2>&1; then
      ok "Dependencias de video-use instaladas"
    else
      fail "No se pudieron instalar las dependencias de video-use"
    fi
    if [ "$ARCH" = "arm64" ] && [ "$(uname -s)" = "Darwin" ]; then WHISPER_PKG="mlx-whisper"; else WHISPER_PKG="faster-whisper"; fi
    uv pip install --quiet --python "$VU_DIR/.venv/bin/python" "$WHISPER_PKG" >/dev/null 2>&1 \
      && ok "Whisper instalado ($WHISPER_PKG)" || fail "No se pudo instalar Whisper ($WHISPER_PKG)"
  fi

  # Reemplaza la transcripción de ElevenLabs por Whisper local
  if [ ! -f "$VU_DIR/helpers/transcribe_elevenlabs.py" ] && grep -qs "ElevenLabs Scribe" "$VU_DIR/helpers/transcribe.py"; then
    cp "$VU_DIR/helpers/transcribe.py" "$VU_DIR/helpers/transcribe_elevenlabs.py"
  fi
  cp -f "$HERE/transcribe.py" "$VU_DIR/helpers/transcribe.py" && ok "Transcripción local con Whisper activada (sin ElevenLabs)"

  # Nota para el agente dentro de la skill
  if ! grep -qs "estudio-reels: configuración local" "$VU_DIR/SKILL.md"; then
    cat >> "$VU_DIR/SKILL.md" <<'EOF'

## estudio-reels: configuración local

This install was customized by estudio-reels. These notes override the Setup section above:

- Transcription runs **locally with Whisper** through `helpers/transcribe.py` (same output format as Scribe). **No `ELEVENLABS_API_KEY` is needed** — never ask for one. Default language is Spanish; pass `--language auto` for other languages.
- Run every helper with this skill's own Python: `<skill_dir>/.venv/bin/python helpers/<name>.py ...`.
- Start shell commands with `export PATH="$HOME/.local/bin:$PATH"` so ffmpeg, ffprobe, node and npx resolve.
- For `transcribe_batch.py`, pass `--workers 1` (the local model runs one file at a time).
- Whisper can miss some hesitations ("eh", "este"); also cut on silences and false starts visible in the timestamps.
- For animation slots use the HyperFrames skills (`/hyperframes`) when installed.
EOF
  fi

  ln -sfn "$VU_DIR" "$SKILLS_DIR/video-use" && ok "Skill video-use registrada en Claude"

  if [ "${SKIP_MODEL:-0}" != "1" ]; then
    echo "   Descargando el modelo de Whisper (~1.5 GB, solo la primera vez)…"
    "$VU_DIR/.venv/bin/python" "$VU_DIR/helpers/transcribe.py" --warmup >/dev/null 2>&1 \
      && ok "Modelo de Whisper listo" \
      || warn "El modelo de Whisper se descargará en la primera transcripción"
  fi
fi

# ----------------------------------------------------------------------------
step "5. Skills de HyperFrames (animaciones, gráficas, textos)"
if command -v npx >/dev/null 2>&1; then
  if npx --yes "hyperframes@$HF_VERSION" skills update >/dev/null 2>&1; then
    ok "Skills de HyperFrames instaladas (v$HF_VERSION)"
  else
    warn "No se pudieron instalar las skills de HyperFrames (Claude puede reintentarlo)"
  fi
else
  warn "Sin Node.js: se omiten las skills de HyperFrames"
fi

# ----------------------------------------------------------------------------
step "6. Skills editar-reel y /editar"
for SK in editar-reel editar; do
  if [ -d "$PKG_SKILLS/$SK" ]; then
    rm -rf "$SKILLS_DIR/$SK"
    cp -R "$PKG_SKILLS/$SK" "$SKILLS_DIR/$SK" && ok "Skill $SK instalada"
  else
    fail "No se encontró la skill $SK en el paquete"
  fi
done

# ----------------------------------------------------------------------------
step "7. Carpeta del proyecto: $REELS_DIR"
mkdir -p "$REELS_DIR/Videos Celular" "$REELS_DIR/videos" "$REELS_DIR/logos" "$REELS_DIR/referencias"
for d in basicos moda branding wellness teclado-y-escritura comida-y-bebida humor-y-reaccion; do
  mkdir -p "$REELS_DIR/efectos/$d"
done
if [ ! -f "$REELS_DIR/CLAUDE.md" ]; then
  cp "$TEMPLATES/CLAUDE.md" "$REELS_DIR/CLAUDE.md" && ok "CLAUDE.md creado (instrucciones del proyecto)"
else
  cp "$TEMPLATES/CLAUDE.md" "$REELS_DIR/CLAUDE.plantilla-nueva.md"
  ok "Ya había un CLAUDE.md; se respetó. La plantilla nueva quedó como CLAUDE.plantilla-nueva.md"
fi
ok "Carpetas listas: Videos Celular, videos, efectos, logos, referencias"

# ----------------------------------------------------------------------------
step "8. Verificación"
command -v ffmpeg  >/dev/null 2>&1 && ok "ffmpeg: $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f1-3)" || fail "ffmpeg no responde"
command -v ffprobe >/dev/null 2>&1 || fail "ffprobe no responde"
command -v node    >/dev/null 2>&1 && ok "node: $(node -v)" || warn "node no responde"
if [ -x "$VU_DIR/.venv/bin/python" ]; then
  "$VU_DIR/.venv/bin/python" "$VU_DIR/helpers/timeline_view.py" --help >/dev/null 2>&1 \
    && ok "Helpers de video-use responden" || fail "Los helpers de video-use no responden"
fi

echo
echo "════════ RESUMEN ════════"
echo "Correctos: ${#OK[@]}   Avisos: ${#WARN[@]}   Errores: ${#FAIL[@]}"
for m in "${WARN[@]+"${WARN[@]}"}"; do echo "⚠️  $m"; done
for m in "${FAIL[@]+"${FAIL[@]}"}"; do echo "❌ $m"; done
echo "Proyecto: $REELS_DIR"
echo "video-use: $VU_DIR"
[ ${#FAIL[@]} -eq 0 ] && exit 0 || exit 1
