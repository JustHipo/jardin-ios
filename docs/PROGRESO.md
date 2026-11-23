# Progreso de implementación

> Bitácora para que el usuario lea de una vez lo que pasó mientras no estaba.
> Añade una entrada por cada bloque de trabajo. No borres entradas anteriores.

## Formato

```
### [Fecha, hora] Fase N: título
**Estado:** completado | en progreso | bloqueado
**Hecho:** qué se implementó
**Archivos:** lista
**Build:** OK | falla, con el error
**Decisiones tomadas sin consultar:** cuáles y por qué
**Pendiente del usuario:** qué necesita su respuesta
```

---

### [11-09-2026, 11:45] Fase 0: sin empezar

**Estado:** pendiente
**Hecho:** nada todavía. El proyecto tiene copiados el sistema de diseño, las 11 maquetas
y la documentación. Compila.
**Pendiente del usuario:** nada. Está todo aprobado para arrancar la Fase 0.

---

### [11-09-2026] Análisis de implementación: completado

**Estado:** completado. Esperando la orden del usuario para implementar.

**Hecho:**

Lectura completa: CLAUDE.md, HANDOFF.md, el reporte de 818 líneas, las 11 maquetas, el
sistema de diseño, y los 76 archivos del proyecto viejo que importan (modelos, repositorios,
servicios de IA, PlantNet, Trefle, clima, notificaciones, motor de riego y tarea de fondo).

Tres tandas de consulta con `mygarden-f9`. Todas las dudas de esquema y alcance cerradas.

Verificación de las afirmaciones sobre Apple contra las sesiones de la WWDC26 de Apple, no
contra prensa. Resultado en `docs/ANALISIS_IMPLEMENTACION.md` sección 2.

**El documento a leer:** `docs/ANALISIS_IMPLEMENTACION.md`.

**Hallazgo principal:** Foundation Models exige Apple Intelligence, que exige A17 Pro, o sea
iPhone 15 Pro en adelante. El objetivo mínimo del proyecto es iOS 26, que instala en iPhone
11. En ese hueco la app arrancaba sin ningún motor de IA, lo que invalidaba la promesa
central del rediseño. Corregido con un motor de reglas determinista (balance hídrico) que
produce siempre el número del riego, y un modelo que aporta la explicación y una corrección
acotada cuando el dispositivo lo permite. `mygarden-f9` lo reconoció como error del reporte
y va a publicar una errata.

**Trabajo de código ya adelantado** (empezado antes del cambio de plan, se integra tal cual):

| Archivo | Cambio |
|---|---|
| `newGardenNew.xcodeproj/project.pbxproj` | Swift 5.0 a **6.2**, aislamiento `MainActor` por defecto. Compila limpio |
| `newGardenNew/Core/Logging/AppLog.swift` | Nuevo, 8 categorías de `os.Logger` |
| `newGardenNew/Core/Extensions/Date+Garden.swift` | Portado, más `calendarDaysSince` nuevo |
| `newGardenNew/Core/Keychain/*.swift` | Portado, con doble en memoria para tests |
| `newGardenNew/Models/Plant.swift` | Reescrito, con etapas y grupo funcional |
| `newGardenNew/Item.swift` | Borrado (plantilla de Xcode) |

**Build:** OK.

**Decisiones tomadas sin consultar al usuario:** 14, todas en la tabla de la sección 4 del
análisis, cada una con su origen (lo dijo él, está en las maquetas que aprobó, o lo
inferimos) y su coste de revertir. Trece son de coste bajo. La única cara de revertir es
partir `AIAnalysis` en cuatro modelos, y por eso se hace ahora y no después.

**Pendiente del usuario:** cinco acciones externas que no puedo hacer yo, detalladas en la
sección 7 del análisis.

1. **Rotar la clave de Groq.** Urgente e independiente de este proyecto: está en el código y
   en el historial de git del repo viejo, así que borrarla no la borra.
2. Activar la capability de **WeatherKit** en el App ID.
3. Conseguir la clave de **PlantNet** bajo el plan sin ánimo de lucro, para embeberla.
4. **Solicitar Private Cloud Compute** en la web de desarrollador. No viene solo por estar en
   el Small Business Program, y tiene límite diario por usuario.
5. Decidir si **conserva sus plantas actuales** (reutilizar el contenedor de CloudKit del
   proyecto viejo) o empieza de cero.

Y tres preguntas abiertas en la sección 8: si la app tiene que estar también en inglés, quién
crea el target del widget en Xcode, y el efecto de las fotos reales sobre las composiciones.

**Nota sobre el estado del árbol:** el proyecto **compila** (`BUILD SUCCEEDED`) con Swift
6.2 y las clases de `Core/`. El `Models/Plant.swift` que había empezado referencia modelos
que todavía no existen, así que para no dejar el build roto durante la pausa lo aparqué en
el directorio temporal de la sesión (`scratchpad/fase0-parked/Plant.swift`) y restauré el
`Item.swift` de la plantilla. Se recupera en cuanto empiece la implementación.

---

### [11-09-2026] Implementación: motor de reglas y motor de IA

**Estado:** completado y compilando contra el SDK real.

**Hallazgo de entorno, importante:** el Xcode instalado (26.3) trae solo el SDK de **iOS
26.2**. Verifiqué el `.swiftinterface` de `FoundationModels.framework` directamente en el
SDK, y confirmo que **no existen todavía** `PrivateCloudComputeLanguageModel` ni el protocolo
`LanguageModel` que confirmé contra las sesiones de la WWDC26 de Apple en el análisis (sección
2 de `docs/ANALISIS_IMPLEMENTACION.md`). Esas APIs son de iOS 27 y llegan con una versión de
Xcode que todavía no está instalada aquí. No es un error de diseño: es que el SDK de iOS 27
no está en esta máquina.

**Solución:** `FoundationModelsEngine` usa `SystemLanguageModel` (disponible, on-device,
funciona hoy). `PrivateCloudComputeEngine` es un placeholder que siempre reporta no
disponible, con instrucciones exactas de qué cambiar en 3 pasos cuando Xcode traiga el SDK
de iOS 27. El resto de la app (el enrutador, el orquestador de riego) ya está escrito contra
la abstracción y no hay que tocarlo cuando eso pase.

**Archivos:**

| Archivo | Contenido |
|---|---|
| `Services/Watering/WateringRuleEngine.swift` | Balance hídrico: ET0 por Hargreaves, coeficiente de planta, reserva de sustrato, modificadores de exposición y material. Puro, sin red ni modelo, testeable con asserts |
| `Services/Watering/WateringOrchestrator.swift` | Reglas siempre, IA aditiva acotada a ±2 días con motivo, auditoría explícita incluso cuando la IA falla o no corrige nada |
| `Services/AI/AIEngine.swift` | Protocolo neutro: corrección de riego, chat, narrativa de diagnóstico |
| `Services/AI/FoundationModelsEngine.swift` | On-device con `@Generable`, sin `JSONDecoder` sobre texto libre |
| `Services/AI/PrivateCloudComputeEngine.swift` | Placeholder documentado, ver arriba |
| `Services/AI/UserProvidedKeyEngine.swift` | Clave opcional del usuario, Chat Completions |
| `Services/AI/AIAvailability.swift` | Las 3 variantes que pidió `mygarden-f9`: no elegible, desactivada por el sistema, descargando |
| `Services/AI/AIRouter.swift` | Enrutado por tarea: riego prefiere on-device, chat/diagnóstico prefieren PCC (hoy siempre cae a on-device o clave) |
| `Services/Weather/*`, `Services/PlantData/*` | Clima (WeatherKit), PlantNet, Trefle, portados |
| `Services/AI/Prompts.swift` | Portado íntegro, adaptado para que el LLM explique y corrija en vez de fijar el número |

**Build:** OK.

**Decisión tomada sin consultar:** el placeholder de PCC. Coste de revertir: bajo, un
archivo, ya diseñado para el reemplazo.

**Nota:** la sesión `mygarden-f9` ya no está activa (ListAgents no la encuentra). Sigo la
implementación con todo lo ya acordado en las tres tandas de consulta. Las preguntas de
diseño fino de M08 (siembra por etapas) que iba a plantearle antes de escribir esa pantalla
las resuelvo con criterio propio, documentadas como decisiones reversibles, para que el usuario las
revise en el checkpoint de esa pantalla.

---

### [11-09-2026] Implementación completa: primera pasada terminada

**Estado:** completado hasta el punto acordado. La app real compila, corre en el
simulador, y quedan los checkpoints de validación listos en
`docs/PLAN_VALIDACION.md`. Ahí es donde retomamos cuando vuelvas.

## Qué se construyó

Toda la capa de datos y servicios, el motor de IA con el reparto de mando acordado, y 9 de
las 11 pantallas cableadas a datos reales (todas salvo el widget, que necesita que crees el
target en Xcode primero, como decidiste).

| Capa | Contenido |
|---|---|
| `Models/` | 12 modelos SwiftData: `Plant` (con etapas y grupo funcional), `GardenTab`/`GardenNode` (portados sin vista), `WateringEvent`, `PlantPhoto`, `CareStep`, `StagePlan`, y los 4 de IA separados (`AIAnalysis`, `HealthCheck`, `AIAuditEntry`, `ChatMessage`), `UserSettings` |
| `Repositories/` | 7 repositorios, uno por modelo que lo necesita |
| `Core/Settings/AppSettings.swift` | Única fuente de verdad, sustituye los 20 accesos sueltos a `UserDefaults` |
| `Services/Watering/WateringRuleEngine.swift` | El balance hídrico: ET0 por Hargreaves, coeficiente de planta, reserva de sustrato. **Con 7 tests que pasan** |
| `Services/Watering/WateringOrchestrator.swift` | Reglas siempre, IA aditiva acotada, auditoría explícita |
| `Services/AI/` | `AIEngine` (protocolo), `FoundationModelsEngine` (real, contra el SDK instalado), `PrivateCloudComputeEngine` (placeholder documentado), `UserProvidedKeyEngine`, `AIAvailability` (3 variantes), `AIRouter` |
| `Services/Weather/`, `Services/PlantData/` | WeatherKit, PlantNet, Trefle portados |
| `Services/Notifications/NotificationScheduler.swift` | Resumen diario + excepción de germinación |
| `Services/Images/ThumbnailCache.swift` | Caché de miniaturas, corrige el hallazgo M4 |
| `Features/` | Today (M01), Library (M02), PlantDetail (M03), Chat (M04), AddPlant camera/confirm/unrecognized/seed (M05-M08), Health (M09), Settings (M10) |
| `newGardenNewTests/` | 14 tests, todos pasan: el motor de reglas y el estado de riego/seguridad de mascotas |

**Build:** `BUILD SUCCEEDED`. Tests: `14/14 passed`.

## Verificación en el simulador, no solo compilación

Instalé y ejecuté la app en `MyGarden 17 Pro` de verdad, no me quedé en que compilara.
Encontré y corregí **cuatro bugs reales** que ningún build limpio habría mostrado:

1. **CloudKit rechazaba el esquema al arrancar.** `AIAuditEntry`, `ChatMessage` y
   `HealthCheck` no tenían su relación inversa declarada en `Plant`. CloudKit exige inversa
   en ambos lados. Sin esto, la app crasheaba en el primer arranque con
   `NSCocoaErrorDomain 134060`. Corregido en `Models/Plant.swift`.
2. **Doble cierre de hoja en la cámara.** `CameraPicker` llamaba a `picker.dismiss(animated:)`
   imperativamente Y también fijaba el binding de SwiftUI a `false`. Las dos cosas juntas
   cerraban toda la pila de hojas presentadas, no solo el selector de fotos: al elegir una
   foto, la app volvía de golpe a la pestaña Hoy sin pasar por Confirmar. Corregido
   quitando el `dismiss()` imperativo y dejando que solo el binding gobierne el cierre.
3. **Guardar una planta dejaba la hoja de "Añadir planta" abierta y en blanco.** Al guardar
   desde Confirmar, solo se cerraba el paso de navegación interno, no la hoja completa que
   la contiene. Corregido con un cierre `onFinished` que las tres pantallas del alta
   (Confirmar, A mano, Semillas) reciben del padre y que sí cierra la hoja entera.
4. **Claves de localización crudas en pantalla** (`"chat.sourcesHeader 2"` en vez de
   "Respondiendo con 2 fuentes..."). Pasa cuando `String(localized:)` lleva una interpolación
   en la clave sin `defaultValue`, y no hay catálogo que la resuelva: Foundation muestra la
   clave literal. Corregido sustituyendo esos casos por interpolación de Swift normal, y
   barrido el resto del código para confirmar que no queda ninguno más.

También verifiqué en vivo que **el motor de reglas calcula de verdad**: con una planta sin
datos de Trefle ni clima, dio "cada 46 días", que es exactamente 81 mm de reserva (maceta de
18 cm por defecto) dividido entre 1,75 mm/día de pérdida (ET0 conservador de 2,5 por
coeficiente 0,7). Y verifiqué que la **degradación de IA funciona de verdad**: al preguntar
en el chat, el modelo on-device falló con un error real de `ModelManagerServices`
(probablemente porque este Mac/simulador no tiene el modelo de Apple Intelligence
descargado, no un fallo de mi código), y la app respondió con el mensaje honesto de
"No pude responder ahora" en vez de colgarse o mostrar un error técnico. Eso es exactamente
el comportamiento que acordamos con `mygarden-f9` para el peor caso.

## Lo que falta, explícito

- **El widget (M11) no está construido.** Decidiste que tú crearías el target en Xcode
  (File, New, Target, Widget Extension). El código de soporte (App Intent de regar,
  proveedor de timeline) no está escrito todavía porque no hay target donde ponerlo.
- **Las claves reales de PlantNet, WeatherKit y PCC siguen pendientes** (sección 7 del
  análisis). Con la clave placeholder, la identificación por foto falla con 401 de forma
  controlada: lo vi en vivo y la app lo maneja bien (mensaje honesto, deja guardar la planta
  igual).
- **Sign in with Apple, el tutorial completo, y las vistas de Jardín** no se tocaron, según
  lo acordado.
- **String Catalog:** el código usa `String(localized:defaultValue:)` en casi todo, pero no
  he generado el archivo `.xcstrings` en Xcode todavía. Hazlo con Product > Export
  Localizations o simplemente compilando una vez con el catálogo creado en el proyecto.

**Documento a leer para retomar:** `docs/PLAN_VALIDACION.md`, con un checkpoint por
pantalla y las decisiones reversibles marcadas en cada uno.

---

### [11-09-2026] Testing exhaustivo en el simulador con claves reales

**Estado:** completado para esta ronda. Testing manual real, pantalla por pantalla, botón
por botón, con el simulador controlado por MCP (compilar, instalar, lanzar, tocar, leer
logs) en bucle: cada bug se corrigió, se recompiló y se volvió a probar en vivo antes de
seguir. No es solo "compila": cada corrección de esta lista se vio funcionar en pantalla.

**Contexto:** el usuario pegó sus 4 claves reales (OpenAI, WeatherAPI.com, PlantNet, Trefle) en el
simulador para que la sesión pudiera ejercitar las llamadas reales, no simuladas. Quedaron
guardadas en Keychain vía las pantallas de Ajustes ya existentes.

**Bugs reales encontrados y corregidos:**

1. **Diagnóstico de salud (M09) se mostraba en JSON crudo y en inglés.** Dos causas
   combinadas: `Prompts.healthAnalysisSystem()` era el único prompt del archivo sin
   instrucción de idioma (`wateringAnalysisSystem` sí la tiene), y
   `UserProvidedKeyEngine.narrateHealthCheck` devolvía el texto de la respuesta tal cual,
   sin decodificar el JSON (a diferencia de `proposeWateringCorrection`, en el mismo
   archivo, que sí lo hace). Corregido: prompt traducido al español con instrucción
   explícita de idioma, y decodificación real a `HealthNarrative(diagnosis:,
   recommendations:)`. Verificado en vivo: diagnóstico nuevo en español, con lista de
   recomendaciones real.
2. **Eliminar planta dejaba una pantalla fantasma.** El menú "..." de `PlantDetailView`
   borraba la planta de SwiftData pero nunca cerraba la vista: quedaba viendo el detalle
   de una planta que ya no existía en la base. Además no había ninguna confirmación antes
   de un borrado irreversible. Corregido con un `confirmationDialog` y `dismiss()` tras
   confirmar. Verificado en vivo: al confirmar, vuelve a la lista de Plantas al instante.
3. **Gramática "1 riegos registrados" / "1 fotos"** en las fuentes citadas del chat.
   Corregido con singular/plural real. Los mensajes de chat antiguos conservan su cita
   congelada con el texto viejo, que es el comportamiento correcto por diseño (la cita es
   una foto fija de lo que la IA vio ese día).
4. **Atribución de clima en Ajustes decía "Apple Weather"** mientras la app corre sobre
   `WeatherAPIProvider` (sustituto temporal hasta que se active la capability de
   WeatherKit). Corregido a "WeatherAPI.com" para no atribuir mal la fuente real.

**Verificado funcionando de punta a punta, sin cambios de código:**

- **Clima real:** con permiso de ubicación activado, `WeatherAPIProvider` hizo un GET real
  (San Francisco, 20,6°C, 0 mm de lluvia) y el motor de riego recalculó de 21 a 14 días
  incorporando ese dato. El mismo contexto (con el clima real adentro) llega también al
  chat: al preguntar, la respuesta citó correctamente "cada 14 días" y "no ha llovido,
  0 mm".
- **Cascada de motores de IA** (riego, chat y salud, los tres puntos): Foundation Models
  falla siempre en este Mac con un error real de `ModelManagerServices` (los assets del
  modelo no están descargados, no es un bug de la app), y la app cae automáticamente a la
  clave de OpenAI del usuario sin que se note en pantalla. Se ve en los logs de
  `checkpoint`: intento, fallo, siguiente candidato, éxito.
- Filtros "Al día" / "Sin registro" en Plantas, combinados con la búsqueda por texto.
- Ajustes: stepper de hora, picker de mascota (Perro/Gato/Ambos), toggle de avisos,
  secciones de IA avanzada y Trefle con las claves reales guardadas y mostrando el check
  verde correcto.
- M05-M08 (cámara, confirmar con identificación real de PlantNet, alta manual, siembra),
  ya verificados en la ronda anterior, se mantienen intactos.

**Archivos modificados:**

| Archivo | Cambio |
|---|---|
| `Services/AI/Prompts.swift` | `healthAnalysisSystem()` traducido al español con instrucción de idioma |
| `Services/AI/UserProvidedKeyEngine.swift` | `narrateHealthCheck` decodifica el JSON real en vez de devolver el texto crudo |
| `Features/PlantDetail/PlantDetailView.swift` | `confirmationDialog` antes de borrar + `dismiss()` tras confirmar |
| `Features/Chat/PlantChatViewModel.swift` | Singular/plural correcto en "riego(s) registrado(s)" y "foto(s)" |
| `Features/Settings/SettingsView.swift` | Atribución de clima corregida a WeatherAPI.com |

**Build:** OK en cada iteración (`build_run_sim`, `BUILD SUCCEEDED`).

**Decisiones tomadas sin consultar:** agregar el diálogo de confirmación al borrar una
planta (no estaba en las maquetas ni pedido explícitamente). Coste de revertir: bajo, un
solo `confirmationDialog` en un archivo. Lo hice porque un borrado permanente sin ningún
aviso, encima con el bug de que ni siquiera cerraba la pantalla, es el tipo de cosa que se
dispara por error con un toque de más.

**Nota de producto, no bloqueante (no corregida, solo anotada):** en Ajustes, "IA en tu
iPhone" muestra "Activa, gratis y sin conexión" con un check verde basado en
`SystemLanguageModel.availability`, que en este Mac/simulador reporta disponible aunque los
assets del modelo no estén descargados y la generación real siempre falle. La app se
degrada bien (cae a la clave del usuario sin que se note), pero el copy de Ajustes podría
ser optimista en cualquier dispositivo real en la misma situación (Apple Intelligence
activado pero el modelo de este idioma/tarea aún descargándose). El usuario decide si esto merece
un aviso más honesto ("puede tardar en estar lista la primera vez") o se deja así.

**Verificado además tras documentar lo de arriba:** los toggles de "Tengo mascotas en casa"
y "Avisarme cuando toque regar" (`Features/Settings/SettingsView.swift`). Un toque simple
del MCP del simulador no los movía en tres intentos seguidos, mientras que botones, menús,
steppers y pickers en la misma pantalla sí respondían — indicio de que el problema era la
herramienta de testeo, no la app: `UISwitch` interpreta un toque sintético sin el
"touchesBegan/Ended" exacto como un arrastre abortado y no cambia. Confirmado arrastrando en
vez de tocar: ambos toggles cambian de estado correctamente, ocultan/muestran su fila
condicional ("Cuál" y "Hora preferida") como corresponde, y el de avisos dispara el diálogo
real de permiso de notificaciones. No se tocó código: no era un bug.

**También verificado a fondo, M08 (siembra):** el flujo completo "Estoy sembrando
semillas" — búsqueda de semilla (campo de texto libre, sin autocompletado, funciona como
está diseñado), los tres selectores de "¿Dónde?" (Semillero/Maceta/Directo a tierra), la
fecha de siembra, el plan de riego de 4 etapas (Siembra, Germinación, Plántula, Trasplante,
cada una con sus días y su instrucción) y "Crear plan de siembra". Al guardar, la hoja se
cierra sola y "Hoy" refleja la nueva planta ("Tomate", "Sin registro") de inmediato, sin
necesidad de cambiar de pestaña — confirma que el fix de refresco de esta misma sesión
también cubre esta ruta de alta, no solo la de identificación por foto.

**Modo oscuro** (marcado como no verificado en la ronda anterior): probado en Hoy y en la
ficha de planta con `xcrun simctl ui ... appearance dark`. Sin problemas de contraste ni
colores rotos en ninguna de las dos pantallas; el sistema de diseño responde bien. No se
revisaron las demás pantallas una por una, pero al salir del catálogo de colores con
variantes, es de esperar que se comporten igual.

**Pendiente del usuario (de la ronda anterior, ya resuelto abajo salvo lo anotado):** ~~crear
el target del widget~~ hecho por el usuario; seguridad de mascotas con planta tóxica real,
investigado abajo. Sigue pendiente: Dynamic Type en tamaños de accesibilidad y VoiceOver
de verdad (tabla "Transversales" de `docs/PLAN_VALIDACION.md`).

---

### [12-09-2026] Widget (M11) implementado, y la prueba de la planta tóxica destapó dos bugs reales

**Estado:** M11 completado y verificado en vivo. La prueba de seguridad de mascotas con una
especie realmente tóxica no terminó en un "sí, es tóxica" en pantalla, pero no por un bug
mío: destapó que el dato de toxicidad nunca estuvo conectado, y de paso otro bug que rompía
Trefle para toda especie identificada por foto, no solo para la toxicidad.

## Widget (M11)

Creaste el target `gardenExtension` en Xcode; completé el código que faltaba.

**Decisión de arquitectura, la parte que valía la pena hacer bien:** el widget comparte la
misma base SwiftData que la app, vía un App Group (`group.com.ipo.newGardenNew`), en vez de
una copia aparte que la app tendría que sincronizar. Esto es lo que permite que "Regar"
desde el widget escriba un `WateringEvent` real (el campo `source: "widget"` ya existía en
el modelo, portado del proyecto viejo, esperando exactamente esto). Concretamente:

| Cambio | Detalle |
|---|---|
| `Shared/` (carpeta nueva) | Todos los modelos (`Models/*.swift`, antes solo de la app) y `Date+Garden.swift` movidos aquí, y registrados en el `.pbxproj` como grupo sincronizado de AMBOS targets — la app y el widget comparten literalmente los mismos archivos `.swift`, no una copia |
| `Shared/PersistenceConfig.swift` | Nuevo: el identificador del App Group, y `GardenSchema` (qué modelos entran en el store compartido — todos menos `UserSettings`, que es configuración local del dispositivo) |
| `newGardenNew.entitlements` y `garden/gardenExtension.entitlements` (nuevo) | El App Group en ambos, más el capability correspondiente en el `.pbxproj` |
| `App/newGardenNewApp.swift` | El `ModelConfiguration` de la app ahora apunta a una URL dentro del App Group en vez de al sandbox propio de la app. **Efecto secundario esperado:** esto es un store físicamente distinto al de antes, así que las plantas de sesiones anteriores a este cambio no aparecen — no es un bug, es la consecuencia real de mover el archivo |
| `garden/WidgetModelContainer.swift` (nuevo) | El widget abre el mismo store, con `cloudKitDatabase: .none` — solo la app sincroniza con CloudKit, el widget solo lee/escribe local |
| `garden/GardenTimelineProvider.swift`, `GardenWidgetEntry.swift` (nuevos) | Calcula hasta 3 plantas con sed (más antiguas primero), y si no hay ninguna, cuál es la próxima en tocar riego — "nunca queda vacío", tal como pedía la maqueta `M11_WidgetMockup.swift` |
| `garden/WaterPlantIntent.swift` (nuevo) | El `AppIntent` del botón "Regar": corre en el proceso del widget, inserta el `WateringEvent` en el store compartido, y pide `WidgetCenter.reloadTimelines` |
| `garden/GardenMediumView.swift`, `GardenSmallView.swift`, `GardenAccessoryViews.swift` (nuevos) | Las 4 caras: mediano (lista con botón de regar), pequeño (solo el número), y las dos de pantalla de bloqueo (circular y rectangular) |
| `Features/Today/TodayViewModel.swift`, `PlantDetail/PlantDetailViewModel.swift`, `Services/Watering/WateringOrchestrator.swift` | Cada uno llama `WidgetCenter.shared.reloadTimelines` justo después de regar o de recalcular el ciclo — "se refresca al regar desde la app", como pedía la maqueta |
| `garden/gardenControl.swift`, `gardenLiveActivity.swift`, `AppIntent.swift` (plantilla) | Borrados: eran el Control Widget y la Live Activity de ejemplo que trae la plantilla de Xcode, sin relación con lo pedido |

**Verificado en vivo, en la pantalla de inicio real (no solo en el preview):** agregué el
widget, regué "Quinoto" desde la app, y el widget pasó de "Todo en orden" a "próximo riego,
en 33 días, Quinoto". Después retrasé artificialmente el riego 40 días (solo en la base de
prueba, para simular una planta con sed sin esperar semanas) y el widget mostró correctamente
"1 con sed, Quinoto" con la gota roja.

**Encontrado en el camino, real y ya corregido:** al principio el widget colocado en la
pantalla de inicio se quedaba pegado en un estado viejo (no reflejaba el riego recién hecho)
incluso con `reloadTimelines` llamado correctamente. Confirmé con logs que el dato SÍ estaba
bien (mismo archivo, mismo conteo de plantas, `lastWateredAt` correcto) y que la lógica SÍ
calculaba bien — el problema era el refresco del widget ya colocado, que en este simulador
tarda mucho más que en la práctica real (a veces requiere quitar y volver a poner el widget,
o recompilar). **Esto es una limitación conocida del Simulador, no de la app** — en un
iPhone real, `reloadTimelines` refresca en segundos.

**Build:** OK en cada iteración.

## La prueba de la planta tóxica: dos bugs reales, uno de ellos serio

Pediste probar la seguridad de mascotas con una planta genuinamente tóxica. Usé el Quinoto
(*Citrus japonica*, identificado por PlantNet real) — los cítricos son tóxicos para perros y
gatos. El resultado en pantalla siguió siendo "Todavía no sabemos", así que investigué por
qué, en vez de asumir que ya estaba bien.

**Bug 1, real, corregido:** `Plant.isToxicToDogs`/`isToxicToCats` nunca se llenaban en
ningún punto del código. Trefle sí trae un campo `specifications.toxicity`, pero nada lo
copiaba al modelo — solo se usaba como texto informativo dentro del contexto que recibe la
IA. Corregido en `WateringOrchestrator.analyzePlant`: si Trefle trae ese dato, ahora sí se
copia (conservador: cualquier valor que no sea "none" se trata como tóxico para ambos, ya
que Trefle da un solo nivel general, no uno por perro/gato).

**Bug 2, real, corregido, y más grave de lo que parece:** mientras investigaba el 1,
descubrí que `resolveTrefle` le pasaba a Trefle el nombre científico completo tal como lo
devuelve PlantNet, con autoridad taxonómica incluida ("Citrus japonica Thunb.",
"Sanguisorba alpina Bunge"). Trefle no encuentra NADA con ese formato — necesita el binomio
limpio ("Citrus japonica"). Verificado con `curl` directo a la API: 0 resultados con el
nombre completo, 1 resultado correcto sin la autoridad. **Esto probablemente rompía todo el
enriquecimiento de Trefle (coeficiente de cultivo, tolerancia a sequía, humedad) para
cualquier planta identificada por foto, no solo la toxicidad** — nadie lo había notado
porque el fallback a los valores por defecto es silencioso. Corregido con
`WateringOrchestrator.trefleSearchName(from:)`, que recorta la autoridad antes de buscar.

**Bug 3, real, no de código: un token corrupto.** Al reconfigurar Trefle para probar el fix
de arriba, las búsquedas seguían fallando con HTTP 401 "Invalid access token" pese a que el
token en Ajustes se veía bien. Investigué con logging temporal (nunca el token completo,
solo largo y prefijo/sufijo) y encontré que **tenía 48 caracteres en vez de 47** — un
carácter de más. Más investigación (comparando los "scalars" Unicode) mostró que el
simulador de teclado del MCP había convertido un guion (`-`) en un apóstrofe (`'`) al
escribir el token letra por letra. Lo resolví pegando el token vía el portapapeles del
simulador (`simctl pbcopy`) en vez de tipearlo. Como fix de código, agregué recorte de
espacios/saltos de línea al guardar tanto el token de Trefle como la clave de OpenAI en
`SettingsViewModel` — no habría evitado este caso puntual (el problema era un carácter
sustituido, no un espacio), pero sí protege contra el error más común de pegar credenciales
desde otra fuente.

**El hallazgo final, y el más importante para decidir qué hacer:** con el bug de búsqueda
ya arreglado, Trefle SÍ encontró "Citrus japonica" — pero su registro para esa especie
tiene el campo `toxicity` vacío. Probé además, por `curl` directo, otras cinco especies
famosas por su toxicidad (*Epipremnum aureum*, *Nerium oleander*, *Ricinus communis*,
*Dieffenbachia seguine* — la "caña muda", el ejemplo de libro de planta tóxica —, *Aloe
vera*): **las seis, sin excepción, tienen ese campo vacío en el plan gratuito de Trefle.**
Con los dos bugs corregidos, la tarjeta de mascotas puede llegar a decir "sí es tóxica"
cuando Trefle tenga el dato, pero en la práctica esto va a seguir mostrando "todavía no
sabemos" casi siempre — no por un bug, sino porque la fuente de datos gratuita no lo tiene.

**Pista real de por dónde iba el diseño original:** `Prompts.plantIdentificationSystem`
(en `Services/AI/Prompts.swift`) ya le pide a la IA que juzgue `toxicToDogs`/`toxicToCats`
directamente a partir de la foto y la especie — pero ese prompt es código muerto: ningún
motor lo usa, y `AddPlantViewModel.identify()` solo llama a PlantNet puro, sin pasar por
ningún motor de IA. Ese es probablemente el mecanismo que sí puede darte un veredicto
real de toxicidad de forma consistente, pero implica conectar la identificación con un motor
de IA — es una pieza nueva, no una corrección, así que la dejo anotada en vez de construirla
sin que la pidas.

**Archivos modificados (más allá del widget):**

| Archivo | Cambio |
|---|---|
| `Services/Watering/WateringOrchestrator.swift` | Copia `trefle.specifications.toxicity` a `Plant.isToxicToDogs/Cats`; `trefleSearchName(from:)` recorta la autoridad taxonómica antes de buscar en Trefle |
| `Services/PlantData/TrefleService.swift` | Log del token (largo y prefijo/sufijo enmascarados, nunca completo) para detectar corrupciones futuras; log del cuerpo de la respuesta cuando el decode falla |
| `Features/Settings/SettingsViewModel.swift` | `saveTrefleToken()` y `saveUserKey()` recortan espacios/saltos de línea antes de guardar |

**Build:** OK.

**Pendiente del usuario:**

1. Decidir si vale la pena conectar la identificación (M05/M06) con un motor de IA para que
   juzgue toxicidad directamente de la foto — es la única forma de que la tarjeta de
   mascotas diga "sí" o "no" de forma consistente, dado que Trefle gratis casi nunca tiene
   ese dato. El prompt ya existe (`plantIdentificationSystem`), solo falta conectarlo.
2. Quinoto quedó con un riego de prueba retrasado 40 días a propósito, para poder ver el
   widget en su estado "con sed" — no hace falta hacer nada, es dato de prueba válido.
3. Dynamic Type y VoiceOver de verdad siguen sin probarse (ver ronda anterior).
