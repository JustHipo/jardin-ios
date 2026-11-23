# Traspaso: de MyGarden a newGardenNew

**Fecha:** 11 de septiembre de 2026
**Escrito por:** la sesión de Claude Code que hizo el análisis y el diseño
**Para:** la sesión de Claude Code que va a implementar

---

## 0. Qué es esto y por qué existe

El usuario (El usuario, habla español) tiene una app iOS llamada **MyGarden**: cuidado de plantas
con identificación por IA, análisis de riego adaptativo según el clima, y detección de
enfermedades. Está funcionalmente completa pero lleva desde marzo sin tocarse.

Se hizo un análisis completo. El resumen en una frase: **la arquitectura es buena, el
producto está construido al revés**. La app le pide al usuario que trabaje para ella
(consigue 4 claves de API, rellena 5 pasos, interpreta JSON de IA) cuando debería ser
al contrario.

Se diseñaron 11 pantallas nuevas, el usuario las revisó en el simulador y **las aprobó**.
Tu trabajo es implementarlas en este proyecto limpio, reutilizando lo que vale del viejo.

---

## 1. Los dos repositorios

### Origen (solo lectura, no lo modifiques)

```
~/proyectos/myGarden/myGarden/
```

76 archivos Swift, 8.052 líneas, repo git con 12 commits. Es la fuente de la lógica de
negocio que se reutiliza. **Ahí está también la pestaña "Rediseño" con las 11 maquetas
corriendo**, por si quieres verlas en contexto.

Su documentación: `myGarden/CLAUDE.md` describe la app tal como está hoy.

### Destino (aquí trabajas)

```
~/proyectos/newGardenNew/newGardenNew/
```

Plantilla limpia de Xcode con SwiftData. Ya compila con el sistema de diseño y las
maquetas copiadas.

---

## 2. Cómo hablarme

Sigo viva como sesión de Claude Code y puedo responderte dudas de diseño, de por qué se
decidió algo, o de dónde está tal cosa en el código viejo.

**Los nombres de sesión CAMBIAN.** No los codifiques en ningún sitio. El procedimiento
fiable es siempre el mismo:

1. Ejecuta `ListAgents`
2. Busca la sesión cuyo nombre empiece por `mygarden`
3. Escríbele con ese nombre exacto

```
SendMessage({ to: "<el nombre que salga en ListAgents>", message: "tu pregunta" })
```

En distintos momentos he sido `mygarden-f9` y `mygarden-22`. Si `ListAgents` no muestra
ninguna sesión `mygarden`, es que se cerró la ventana: entonces las dudas de diseño van
directas al usuario, y el reporte más esta guía son la única fuente de verdad.

### Cuándo conviene preguntarme

- **Por qué** se decidió algo así y no de otra forma. Tengo el razonamiento completo y
  el contexto de la conversación con el usuario, que no está todo escrito en los documentos
- Dónde está una función concreta en el código viejo, o si vale la pena reutilizarla
- Si una pantalla debe comportarse de cierta manera en un caso que el mockup no cubre
- Si encuentras una contradicción entre el reporte y el código

### Cuándo NO preguntarme

- Cosas que están en `docs/REPORTE_ESTADO_Y_REDISENO.md`. Léelo primero, es largo pero
  está indexado
- Decisiones de implementación que puedes tomar tú con criterio
- Permiso para hacer lo que ya está aprobado en el roadmap

### Advertencia sobre autonomía

El usuario se va un rato y nos deja trabajando. Eso significa:

- **No hagas nada irreversible sin él.** Nada de commits, push, borrar archivos suyos,
  ni tocar el repo viejo
- Si te bloqueas en una decisión de producto que cambia el resultado de forma importante,
  **pregúntame a mí primero**. Solo deja algo esperando al usuario si de verdad ninguno
  de los dos puede decidirlo
- Documenta en `docs/PROGRESO.md` lo que vayas haciendo, para que cuando vuelva lo lea
  de una vez en vez de reconstruirlo del historial

---

## 3. Decisiones ya tomadas (no las vuelvas a abrir)

El usuario ya aprobó todo esto. Si crees que alguna está mal, dímelo a mí antes de
cambiarla por tu cuenta.

### 3.1 Motor de IA: enrutado por tarea, no cadena de prioridad

Este es **el cambio conceptual más importante**. La app vieja tiene un
`AIServiceFactory.makeService()` que da prioridad absoluta a la clave del usuario para
todo, incluido el análisis diario en segundo plano de cada planta. Eso gasta dinero en la
tarea que menos lo necesita.

| Tarea | Motor | Razón |
|-------|-------|-------|
| Ajuste de riego diario | Foundation Models on-device | Es inferencia sobre un contexto que la app ya construye. El volumen es alto: 10 plantas por 365 días son 3.650 llamadas al año |
| Chat sobre una planta | Private Cloud Compute, con caída a on-device sin red | Conversación multi-turno sobre 6 fuentes |
| Diagnóstico por foto | PlantNet + PCC | PlantNet clasifica, el LLM explica |
| Identificar especie | **Siempre PlantNet** | Ningún LLM generalista supera a un clasificador entrenado con 50.000 especies |

OpenAI y Anthropic **no se eliminan**, se degradan: pasan a ser una preferencia opcional
plegada en Ajustes, que nunca gobierna el trabajo en segundo plano.

**Verifica esto antes de construirlo.** El reporte se apoya en material de la WWDC26 sobre
Foundation Models y Private Cloud Compute (visión on-device en iOS 27, tramo gratuito de
PCC para el App Store Small Business Program con menos de 2 millones de descargas).
Contrasta los detalles con la documentación oficial de Apple antes de comprometer la
arquitectura. El plan de contingencia es quedarse en on-device puro.

### 3.2 Cuatro pestañas, organizadas por intención

`Hoy` · `Plantas` · `Salud` · `Ajustes`

La app vieja tenía `Plantas` · `Análisis` · `Ajustes`. "Análisis" no es una intención del
usuario, es una categoría técnica: nadie abre la app pensando "voy a analizar", piensa
"¿tengo que regar algo?". Por eso **Hoy** es la pantalla de entrada y es una agenda, no un
inventario alfabético.

### 3.3 El widget es requisito, no extra

Decisión explícita del usuario. Regar ocurre varias veces por semana y hoy cuesta tres
toques después de abrir la app. Con App Intents interactivos el toque en la gota del widget
registra el riego sin abrir nada, y el mismo intent sirve para Siri y Atajos.

### 3.4 Tres funciones nuevas que pidió el usuario

**Planta no reconocida (M07).** Cuando ni PlantNet ni el LLM identifican la especie, no se
puede dejar al usuario en un callejón sin salida. Se pregunta por lo que sí puede ver
(¿a qué se parece? ¿hoja fina o ancha?) y se deduce el cuidado del **grupo funcional**, no
de la especie. Botánicamente esto funciona: una suculenta se riega como suculenta aunque
no sepas si es una *Echeveria* o una *Haworthia*.

**Siembra desde semilla (M08).** Esto **toca el modelo de datos**. Una semilla no tiene
ciclo de riego fijo, tiene etapas, y cada etapa quiere un riego distinto:

| Etapa | Riego | Días |
|-------|-------|------|
| Siembra | Sustrato húmedo constante | 0 a 3 |
| Germinación | Pulverización 2 veces al día | 4 a 10 |
| Plántula | Cada 2 días | 11 a 25 |
| Trasplante | Cada 3 días | 26 en adelante |

El modelo `Plant` viejo solo tiene `waterEveryDays` y `waterEveryDaysAdjusted`. Hace falta
un concepto de etapa de crecimiento con su propio plan, y transiciones entre etapas.
También cambia el patrón de notificaciones (dos veces al día durante la germinación).

**Chat por planta (M09... en realidad M04).** La diferencia con un chatbot genérico es el
**anclaje**: la IA responde sobre esta planta con las 6 fuentes que la app ya tiene
(PlantNet, Trefle, WeatherKit, historial de riego, fotos, contexto escrito por el usuario).

Tres reglas de diseño no negociables:
1. El contexto es visible: panel plegable que enumera las 6 fuentes
2. Cada afirmación cita su fuente con un chip
3. Si algo no está en las fuentes, la IA lo dice en vez de rellenarlo

### 3.5 Otras decisiones

- **iOS 26 mínimo.** Mejora progresiva bajo `#available(iOS 27)` para visión on-device y PCC
- **WeatherKit reemplaza a WeatherAPI.com**: viene incluido en la cuenta de desarrollador y
  elimina otra clave de API
- **La clave de PlantNet va embebida** en la app bajo su plan sin ánimo de lucro, no se le
  pide al usuario
- **Trefle pasa a opcional** con degradación elegante: sin clave la app funciona igual con
  menos precisión botánica
- **Alta de planta en 2 pasos**, no 5. El bloque de contexto libre se mueve a *después* de
  guardar, como tarjeta opcional de "mejora la precisión"
- **Regar es un toque, con deshacer** en lugar de confirmación previa
- **La racha estilo Duolingo se elimina o se rehace.** Regar no es diario, así que una racha
  diaria es una métrica que el usuario no puede ganar. Se propone reemplazarla por salud del
  jardín (porcentaje de plantas en verde en 30 días)

---

## 4. Qué reutilizar del proyecto viejo

### Copiar casi tal cual

| Qué | Dónde está | Nota |
|-----|-----------|------|
| Modelos SwiftData | `myGarden/Models/` | Plant, GardenTab, GardenNode, WateringEvent, AIAnalysis, CareStep, PlantPhoto, UserSettings. Hay que añadirles el concepto de etapa de crecimiento |
| Repositorios | `myGarden/Repositories/` | Patrón correcto |
| `PlantNetService` | `myGarden/Services/PlantData/` | Identificación y enfermedades. Funciona bien |
| `TrefleService` | `myGarden/Services/PlantData/` | |
| `WeatherCache` | `myGarden/Services/Weather/` | Actor con TTL de 1 h e historial de 7 días. Bien hecho |
| `KeychainService` | `myGarden/Core/Keychain/` | |
| `Prompts.buildWateringContext` | `myGarden/Services/AI/Prompts.swift` | **Esta función es excelente.** Serializa un JSON con datos de la planta, clima, umbrales botánicos de Trefle, seguridad para mascotas e historial. Consérvala entera |
| Configuración dual de `ModelContainer` | `myGarden/myGardenApp.swift` | CloudKit para los datos, local para los ajustes |

### NO copiar

| Qué | Por qué |
|-----|---------|
| `GroqService.swift` | Tiene una **clave de API escrita en el código fuente** (línea 12). Está en el binario y en el historial de git. Hay que rotarla, y Groq desaparece del diseño nuevo |
| `BackgroundAnalysisScheduler` tal cual | Crea su **propio** `ModelContainer` sin las configuraciones de la app, así que escribe en otra base de datos. Además recorre todas las plantas en secuencia dentro de un presupuesto de 30 segundos. Rehacer con el contenedor compartido y lotes con presupuesto |
| Los 20 accesos sueltos a `UserDefaults` | `UserSettings` existe pero nadie lo consulta en el camino crítico. Unificar en un `AppSettings` con una sola fuente de verdad. Esto es importante: la seguridad para mascotas depende hoy de una clave de texto sin tipar |
| `AIServiceFactory` | La cadena de prioridad es el error de diseño descrito en 3.1 |
| Los 59 `print()` | Usar `os.Logger` con categorías |
| Los `try? context.save()` | 10 apariciones que se tragan errores en silencio |

---

## 5. Plan de implementación

| Fase | Contenido | Resultado |
|------|-----------|-----------|
| **0. Base** | Subir Swift a 6.0. Portar modelos, repositorios y servicios reutilizables. Configuración dual de `ModelContainer`. `AppSettings` unificado. `os.Logger` | El proyecto tiene datos y servicios, sin interfaz nueva |
| **1. Sistema de diseño** | Ya está copiado. Revisarlo, completarlo si falta algún componente, y verificar contraste y Dynamic Type | La base visual es sólida |
| **2. Motor de IA** | `AIEngine` como protocolo. `FoundationModelsEngine` con `@Generable`. Enrutado por tarea. `AIAuditTrail` | La app funciona completa sin ninguna clave |
| **3. Las 4 pestañas** | M01 Hoy, M02 Plantas, M09 Salud, M10 Ajustes | El esqueleto de la app nueva |
| **4. Ficha y alta** | M03 ficha, M05 y M06 alta en 2 pasos | Ciclo completo de uso |
| **5. Casos reales** | M07 planta no reconocida, M08 siembra por etapas | Deja de fallar en los casos que la app vieja no cubre |
| **6. Widget y chat** | M11 widget con App Intents, M04 chat anclado | Regar sin abrir la app, preguntar sin adivinar |
| **7. Pulido** | Hápticas, transiciones, accesibilidad, tests al 80% | Calidad comercial |

Las maquetas de cada fase ya están en `newGardenNew/Mockups/Screens/`. **El contrato es que
la pantalla real sea visualmente equivalente a la maqueta aprobada.** Si te desvías,
pregunta antes.

---

## 6. Lo que el usuario todavía no ha decidido

Si surgen, pregúntale a él (o a mí si es de diseño):

1. **Las miniaturas son degradados con un símbolo**, no fotos reales. Con fotos de verdad
   las pantallas cambiarán de aspecto y puede que la composición haya que ajustarla
2. **La pestaña Salud separada** puede ser demasiado si diagnostica poco. Se podría fusionar
   dentro de Hoy
3. **"Todo en orden" plegado** en M01: con 40 plantas quizá quiera verlas sin desplegar
4. **La vista de Jardín** (nodos sobre una foto, con zoom) existe en el código viejo pero
   está desactivada. No está en el diseño nuevo. Preguntar si la quiere de vuelta
5. **Qué hacer con la racha** (ver 3.5)

---

## 7. Avisos prácticos

**El proyecto viejo no compilaba** cuando empecé. Xcode había borrado 13 líneas del
`project.pbxproj` (la excepción que impide que `Info.plist` se copie dos veces) al abrirlo
mientras la carpeta de fuentes no estaba en disco. Ya está arreglado. Lección: no abras un
proyecto de Xcode cuyas fuentes no estén completas, porque Xcode "limpia" referencias que
cree rotas y esa limpieza se guarda.

**El código fuente del proyecto viejo estuvo perdido** en iCloud Drive, no en
`Documents/CODE`. Ya se copió a local. No trabajes proyectos de Xcode dentro de iCloud Drive.

**Simulador:** usa `MyGarden 17 Pro` (iOS 26.3), ya creado y arrancado.

```bash
xcodebuild -project newGardenNew.xcodeproj -scheme newGardenNew \
  -destination 'platform=iOS Simulator,name=MyGarden 17 Pro' -configuration Debug build
```

---

## 8. Por dónde empezar

1. Lee `docs/REPORTE_ESTADO_Y_REDISENO.md` entero. Es largo pero es el contexto completo
2. Mira los 4 PNG de `docs/diagrams/`
3. Abre las maquetas: compila este proyecto y mira `Mockups/Screens/` en el canvas de Xcode,
   o corre el proyecto viejo y ve a la pestaña "Rediseño"
4. Escríbeme para confirmar que entendiste el encargo y plantearme lo que no te cuadre
5. Empieza la **Fase 0**

Suerte.
