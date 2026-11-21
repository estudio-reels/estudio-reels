# 🎬 Estudio de Reels

Edita tus Reels de Instagram y TikTok hablándole a Claude. Tú te grabas con el celular y Claude:

- Corta silencios, muletillas y tomas repetidas, y deja la versión que suena mejor.
- Pone subtítulos animados palabra por palabra.
- Agrega títulos, cifras animadas, gráficas, logos y tu cara en un círculo cuando aparece un dato.
- Mete efectos de sonido (whoosh, ding, pop…) a volumen que no tapa tu voz.
- Te entrega el video vertical listo para publicar, con caption sugerido.

La transcripción es **local y gratis** (Whisper). No necesitas cuentas de ElevenLabs ni API keys.

---

## Qué necesitas
- Una **Mac con chip Apple** (M1 o más nueva). Con Intel también funciona, pero más lento.
- Una cuenta de **Claude Pro o Max** (Claude Code viene incluido).
- La **app de Claude** para Mac: [claude.com/download](https://claude.com/download).
- ~8 GB libres en disco.

## Instalación (una sola vez)

1. Abre la app de Claude e inicia sesión con **tu** cuenta.
2. En **Finder**, crea una carpeta llamada **Reels** en tu carpeta de usuario.
3. En la app de Claude, entra a la pestaña **Code**, elige **Local** y selecciona la carpeta **Reels**.
4. Pega este mensaje y presiona Enter:

```
Instala el Estudio de Reels desde https://github.com/estudio-reels/estudio-reels siguiendo su archivo INSTALAR.md. Usa esta carpeta como mi proyecto.
```

5. Cuando Claude pida permiso, dale **Permitir**. Si macOS pide instalar "herramientas de línea de comandos", dale **Instalar**.

Tarda entre 15 y 30 minutos. Al final Claude te dice qué quedó listo.

> **¿Usas Claude Code en la Terminal?** También puedes instalarlo como plugin:
> ```
> /plugin marketplace add estudio-reels/estudio-reels
> /plugin install estudio-reels@estudio-reels
> ```
> y luego escribe: *"instala el estudio de Reels"*.

## Uso diario

1. Graba en vertical y pasa los videos (por AirDrop o cable, no por WhatsApp) a la carpeta **Videos Celular**.
2. Abre Claude → **Code** → carpeta **Reels**. Usa una **sesión nueva para cada Reel**.
3. Escribe **`/editar`**. Claude te hace las preguntas del Reel en cajas (marca, tono, duración, gancho, datos, logo, sonidos, cierre) y arranca. También puedes adelantar datos: `/editar Nike, tono divertido`.

   Si prefieres escribirlo todo tú, este es un buen primer mensaje:

```
Editemos lo de Nike que grabé hoy.
Tema: cómo nació Nike y el logo de $35
Tono: informativo y ágil
Duración: máx. 45 s
Gancho: "¿Sabías que el logo de Nike costó 35 dólares?"
Datos a resaltar: 1964 (fundación), $35 (el logo), 1971 (nace el nombre)
Logos: logos/nike.svg
Sonidos: branding
Cierre: "Sígueme para más historias de marcas"
Muéstrame el plan antes de editar. Respuestas cortas.
```

4. Aprueba el plan, revisa el video y pide cambios **todos en un solo mensaje**.

### Otras cosas que puedes pedir
- **"Define mi estilo"**: pon 2–3 Reels que te gusten en `referencias/` y Claude arma tu estilo (fuente, colores, ritmo).
- **"Organiza la bandeja"**: acomoda y renombra tus videos sin editar.
- **"¿Qué videos ya no se usaron?"**: lista lo que sobra en la bandeja.
- **"Repara el estudio de Reels"** o **"actualiza el estudio de Reels"**: vuelve a correr la instalación.

## Carpetas
```
Reels/
├── CLAUDE.md          ← tus instrucciones y estilo (puedes editarlo)
├── Videos Celular/    ← echa aquí tus videos crudos
├── videos/            ← Claude crea una carpeta por Reel; el final queda en edit/final.mp4
├── efectos/           ← sonidos por estilo + LICENCIAS.md
├── logos/             ← logos en PNG transparente o SVG
└── referencias/       ← Reels que te inspiran
```

## Consejos
- Para ahorrar uso de tu plan: una sesión por Reel, todo lo que quieres en el primer mensaje, y 2–3 animaciones fuertes en lugar de 10.
- Logos: úsalos sin modificarlos y sin que parezca patrocinio. Bájalos del press kit de la marca o de Wikimedia Commons.
- Efectos: solo con licencia de uso comercial (quedan registrados en `efectos/LICENCIAS.md`).

## Créditos
Construido sobre proyectos de código abierto:
- [video-use](https://github.com/browser-use/video-use) de Browser Use (MIT)
- [HyperFrames](https://github.com/heygen-com/hyperframes) de HeyGen (Apache-2.0)
- [Whisper](https://github.com/openai/whisper) de OpenAI (MIT), vía mlx-whisper / faster-whisper

Este paquete no incluye su código: lo descarga de sus repositorios oficiales durante la instalación.
