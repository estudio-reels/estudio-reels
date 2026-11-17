---
name: editar-reel
description: Edita Reels de Instagram/TikTok de alguien hablando a cámara dentro de un proyecto del Estudio de Reels (carpeta con CLAUDE.md, "Videos Celular", videos/, efectos/, logos/). Úsala cuando digan "editemos…", "edita el reel de…", "organiza la bandeja", "define mi estilo" o pidan cambios a un Reel.
---

# Editar un Reel

El `CLAUDE.md` de la carpeta del proyecto manda: estilo, reglas de cortes, subtítulos, layout, sonidos. Léelo siempre primero. Esta skill solo define el flujo.

Habla en español, simple y **breve**. La persona suele tener plan Pro: ahorra tokens (respuestas cortas, sin repetir lo que ya se ve, sin re-renders innecesarios).

## Preparación técnica (cada sesión)
- `export PATH="$HOME/.local/bin:$PATH"` antes de cualquier comando.
- Herramientas de video: skill **video-use** (`~/.claude/skills/video-use`). Corre sus helpers con `~/.claude/skills/video-use/.venv/bin/python`. La transcripción es Whisper local: **nunca pidas API key de ElevenLabs**.
- Animaciones: skills de **HyperFrames** (`/hyperframes`).
- Si algo de esto falta o falla, usa la skill **instalar-estudio-reels** para reparar (o pide a la persona que diga "repara el estudio de Reels").

## Flujos

### "Editemos lo de X que grabé hoy"
1. **Bandeja**: busca en `Videos Celular/` las tomas de ese Reel (fecha de grabación con `ffprobe` → `creation_time`; si hay varias marcas ese día, transcribe para identificar). Crea `videos/AAAA-MM-DD_marca/` y mueve las tomas renombradas `marca_toma01…` en orden. No borres nada.
2. **Transcribe** con `transcribe_batch.py <carpeta> --workers 1` y empaqueta con `pack_transcripts.py`.
3. **Plan** en máximo 10 líneas (duración, gancho, qué se corta, datos/animaciones con segundo aproximado, logos, sonidos). Usa los datos que la persona dio en su mensaje; no investigues de más. **Espera OK.**
4. **Ejecuta** siguiendo SKILL.md de video-use: cortes en límites de palabra, subtítulos, layout cara/círculo, animaciones HyperFrames (máx. 2–3), efectos de `efectos/` a volumen bajo, render 1080×1920.
5. **Revisa** el render (frames clave, audio sin clics, subtítulos dentro de zonas seguras) antes de entregar.
6. **Entrega**: ruta de `edit/final.mp4`, duración, resumen de 3–5 líneas y caption propuesto. Escribe `edit/notas.md`.

### Cambios
- Aplica **solo** lo pedido. Reusa transcripciones y clips ya generados. Si piden varios cambios, hazlos todos en un solo render.

### "Organiza la bandeja"
- Solo el paso 1 para todo lo que haya en `Videos Celular/`. Muestra la lista propuesta y espera OK antes de mover. Lo que no puedas asignar se queda en la bandeja.

### "Define mi estilo"
- Analiza los videos de `referencias/` (ritmo de cortes, subtítulos, fuentes, colores, animaciones, sonidos). Propón un estilo con color de acento y fuente. Al aprobarlo, actualiza la sección "Estilo visual" del `CLAUDE.md`.

### "¿Qué videos ya no se usaron?"
- Lista los archivos de `Videos Celular/` que no están en ninguna carpeta de `videos/`. No borres: la persona decide.

## Reglas
- Nunca borres ni modifiques los videos originales.
- Nunca modifiques un logo (solo animarlo).
- Solo sonidos con licencia comercial registrada en `efectos/LICENCIAS.md`.
- Si falta un logo, pide que lo pongan en `logos/` o propone una fuente oficial.
