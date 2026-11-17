---
name: instalar-estudio-reels
description: Instala o actualiza el Estudio de Reels en esta Mac (edición de Reels/TikTok con Claude, transcripción local con Whisper, animaciones HyperFrames, carpeta de proyecto y kit de efectos de sonido). Úsala cuando pidan instalar, configurar, reparar o actualizar el estudio de Reels.
---

# Instalar el Estudio de Reels

Vas a dejar lista una computadora para que alguien sin conocimientos técnicos edite Reels hablándole a Claude. Háblale **en español, simple y breve**. Haz todo tú; solo pide a la persona lo que no puedes hacer (aprobar permisos, un diálogo de macOS, bajar un archivo a mano).

Todos los archivos de esta skill están junto a este SKILL.md: `scripts/`, `templates/`, `references/`.

## 1. Dónde va el proyecto
- Si la sesión ya está abierta en una carpeta pensada para Reels (por ejemplo se llama "Reels" o está vacía), úsala como proyecto.
- Si no, usa `~/Reels`.
- No preguntes salvo que sea ambiguo.

Dile a la persona en una línea qué vas a hacer y que tarda 15–30 minutos.

## 2. Correr el instalador
```bash
bash "<dir_de_esta_skill>/scripts/instalar.sh" "<carpeta_del_proyecto>"
```
- Tarda varios minutos (descarga el modelo de Whisper de ~1.5 GB). Córrelo en segundo plano o con un timeout largo y revisa la salida al terminar.
- No uses `sudo`. Si macOS muestra un diálogo para instalar "herramientas de línea de comandos", pide a la persona que le dé **Instalar** y espera.
- Al final imprime un **RESUMEN**. Por cada ❌ o ⚠️, investiga y arréglalo tú (reintenta el paso, usa otra fuente, instala de otra forma sin sudo). El script es idempotente: puedes volver a correrlo.
- Si `npx hyperframes skills update` falló, reintenta: `export PATH="$HOME/.local/bin:$PATH"; npx --yes hyperframes@0.9.63 skills update` (usa siempre esa versión fija).

## 3. Kit de efectos de sonido
Lee `references/efectos.md` y descarga el kit a `<proyecto>/efectos/` con su `LICENCIAS.md`.
- Solo licencias de uso comercial sin atribución (CC0 o equivalente).
- Si un sitio bloquea la descarga, no insistas: déjalo en `efectos/PENDIENTES.md` con el link.
- Si tarda mucho, prioriza `basicos/` y deja el resto para después (díselo a la persona).

## 4. Prueba real
Genera un video de prueba con voz y verifica que la transcripción funcione:
```bash
export PATH="$HOME/.local/bin:$PATH"
T="$(mktemp -d)"
say -v Paulina "Hola, esta es una prueba del estudio de Reels. Eh, este, todo funciona." -o "$T/voz.aiff" 2>/dev/null \
  || say "Hola, esta es una prueba del estudio de Reels." -o "$T/voz.aiff"
ffmpeg -y -loglevel error -f lavfi -i color=c=black:s=1080x1920:r=30 -i "$T/voz.aiff" -shortest -c:v libx264 -c:a aac "$T/prueba.mp4"
~/Developer/video-use/.venv/bin/python ~/Developer/video-use/helpers/transcribe.py "$T/prueba.mp4"
```
Debe imprimir `words:` con un número mayor a 0. Si falla, arréglalo antes de seguir. Borra la carpeta temporal al final.

## 5. Entregar
Dile a la persona, en máximo 8 líneas:
- Qué quedó instalado (sin jerga).
- Que, para editar, abra Claude → pestaña **Code** → carpeta del proyecto, o en Terminal `cd <proyecto>` y `claude`.
- Que eche sus videos crudos en **"Videos Celular"**.
- Que un buen primer mensaje es: *"Editemos lo de [marca] que grabé hoy"*.
- Que para definir su estilo ponga 2–3 Reels de ejemplo en `referencias/` y diga *"define mi estilo"*.
- Si quedaron sonidos en `efectos/PENDIENTES.md`, que los baje cuando pueda.
