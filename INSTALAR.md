# Instrucciones de instalación (para Claude)

Si estás leyendo esto porque alguien te pidió instalar el Estudio de Reels desde este repositorio:

1. Descarga este repositorio a `~/Developer/estudio-reels`:
   - Si `git` funciona (en Mac: `xcode-select -p` responde): `git clone https://github.com/estudio-reels/estudio-reels ~/Developer/estudio-reels` (o `git -C ~/Developer/estudio-reels pull` si ya existe).
   - Si no: descarga https://codeload.github.com/estudio-reels/estudio-reels/tar.gz/refs/heads/main con `curl` y descomprímelo ahí.
2. Copia la skill de instalación para que quede disponible después: `mkdir -p ~/.claude/skills && cp -R ~/Developer/estudio-reels/skills/instalar-estudio-reels ~/.claude/skills/`.
3. Lee `~/Developer/estudio-reels/skills/instalar-estudio-reels/SKILL.md` y síguelo de principio a fin. Esa skill es la fuente de verdad.

Habla con la persona en español, simple y breve. No uses `sudo`.
