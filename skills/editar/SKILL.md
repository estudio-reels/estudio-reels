---
name: editar
description: Arranca la edición de un Reel nuevo haciendo las preguntas del brief (marca, tema, tono, duración, gancho, datos, logos, sonidos, cierre) en cajas de pregunta, y luego sigue el flujo de editar-reel. Se usa escribiendo /editar.
argument-hint: "[marca o detalles opcionales]"
disable-model-invocation: true
---

# /editar: brief guiado para un Reel nuevo

Objetivo: que la persona no tenga que acordarse del primer mensaje. Tú le preguntas todo con **cajas de pregunta** (herramienta AskUserQuestion) y después editas.

Habla en español, simple y **muy breve**. No expliques el proceso: pregunta y ya.

Lo que la persona escribió después de `/editar` (puede venir vacío): **$ARGUMENTS**
Si ahí ya viene algún dato (por ejemplo la marca o el tono), no lo vuelvas a preguntar.

## 1. Mira la carpeta (sin decir nada)
Antes de preguntar, revisa rápido para armar opciones reales:
- `Videos Celular/`: qué videos hay y de qué fechas (`ffprobe` → `creation_time`, o la fecha del archivo).
- `logos/`: qué logos hay.
- `efectos/`: qué carpetas de sonidos hay.

## 2. Pregunta en cajas (máximo 3 rondas)
Usa AskUserQuestion con hasta 4 preguntas por ronda. Cada pregunta trae 2–4 opciones; la caja siempre deja escribir en **"Other"**, así que para respuestas libres pon opciones útiles y aclara en la descripción "o escríbelo en Otro". La opción recomendada va primero.

**Ronda 1**
1. **Marca**: ¿De qué marca es el Reel? Opciones: marcas que se deduzcan de los logos o de los nombres de archivo recientes; si no hay pistas, "Te la escribo" (y que la escriba en Otro).
2. **Grabación**: ¿Cuándo lo grabaste? Opciones: Hoy / Ayer / la fecha más reciente que encontraste en la bandeja. Sáltala si en la bandeja solo hay videos de un día.
3. **Tono**: Divertido / Elegante / Informativo / Inspirador.
4. **Duración**: 30–45 s (recomendado) / Máx. 60 s / Lo más corto posible.

**Ronda 2**
5. **Tema**: ¿De qué trata? Opciones: "Sácalo de lo que digo en el video" (recomendado) / "Te lo escribo" (en Otro).
6. **Gancho**: ¿Con qué frase abrimos? Opciones: "Elige tú la más fuerte" (recomendado) / "Te la escribo" (en Otro).
7. **Datos a resaltar** (tarjeta animada + cambio a círculo): Opciones: "Sácalos tú de lo que digo" (recomendado) / "Te los escribo" (en Otro, uno por línea, por ejemplo "1964: fundación"). Máximo 3–4 datos.
8. **Logo**: Opciones: el archivo de `logos/` que coincida con la marca, si existe / "Búscalo tú" / "Sin logo".

**Ronda 3**
9. **Sonidos**: Opciones: la carpeta de `efectos/` que mejor encaje con el tono (recomendada) y otras 1–3 carpetas que existan.
10. **Cierre**: Opciones: "Sígueme para más historias de marcas" (recomendado) / "Sin cierre" / "Te lo escribo" (en Otro).

Si una respuesta de "Otro" no queda clara, no hagas otra ronda: usa tu mejor criterio y menciónalo en el plan.

## 3. Arma el brief y sigue el flujo normal
Con las respuestas, arma internamente este brief (no lo muestres completo):

```
Editemos lo de [marca] que grabé [fecha].
Tema: … · Tono: … · Duración: … · Gancho: …
Datos a resaltar: …
Logos: … · Sonidos: carpeta … · Cierre: …
```

Después sigue la skill **editar-reel**, flujo *"Editemos lo de X que grabé hoy"*: bandeja → transcripción → plan → ejecución → revisión → entrega. Respeta siempre el `CLAUDE.md` del proyecto.

- Lo que la persona dejó en "Sácalo tú" / "Elige tú" lo decides con la transcripción.
- **Plan en máximo 10 líneas y espera su OK** antes de cortar.
- Respuestas cortas, sin explicaciones largas.
