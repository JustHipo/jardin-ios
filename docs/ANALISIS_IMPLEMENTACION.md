# Análisis de implementación

**Fecha:** 11 de septiembre de 2026
**Escrito por:** la sesión de Claude Code que va a implementar
**Estado:** análisis terminado, esperando la orden del usuario para construir

Este documento es el paso previo a escribir la app. Recoge lo que verifiqué, lo que
encontré que no estaba previsto, las decisiones cerradas con la sesión de diseño
(`mygarden-f9`), el inventario de trabajo y lo que necesito del usuario.

---

## 1. Punto de partida verificado

Lo que dice el traspaso coincide con lo que hay en disco, con un matiz.

| Comprobación | Resultado |
|---|---|
| El proyecto compila de base | Sí, `BUILD SUCCEEDED` antes de tocar nada |
| Sistema de diseño copiado | Sí, `DSTokens.swift` y `DSComponents.swift` |
| 11 maquetas | Sí, las leí enteras, son el contrato visual |
| 11 colorsets con variante clara y oscura | Sí |
| Simulador `MyGarden 17 Pro` | Disponible |
| Proyecto viejo intacto | Sí, no lo he tocado ni lo tocaré |

**El matiz:** el `CLAUDE.md` dice que las maquetas están enganchadas en `ContentView.swift`
bajo `#if DEBUG`. No es así: `ContentView.swift` es todavía la plantilla de Xcode con
`Item`. Las maquetas solo se ven desde el canvas de Xcode. No es un problema, pero conviene
saberlo si alguien intenta verlas ejecutando la app.

**Un punto a favor que no estaba anotado:** el target usa grupos sincronizados con el
sistema de archivos (`PBXFileSystemSynchronizedRootGroup`). Los archivos nuevos entran en el
target por el hecho de existir en disco. No hay que editar el `project.pbxproj` a mano para
añadir código, que es justo la operación que rompió el proyecto viejo en su día.

### Trabajo ya adelantado

Antes de que llegara el cambio de plan había empezado la Fase 0. Lo hecho se integra tal
cual en la implementación completa:

- Swift subido de 5.0 a **6.2** en los 6 bloques de configuración, con
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
  **Compila limpio, sin un solo aviso de concurrencia.** Esto no era obvio y era el riesgo
  principal de la Fase 0.
- `Core/Logging/AppLog.swift` con 8 categorías de `os.Logger`.
- `Core/Extensions/Date+Garden.swift`, con un `calendarDaysSince` nuevo que el código viejo
  no tenía y que hace falta para que "hace 1 día" signifique lo que el usuario entiende.
- `Core/Keychain/` con el protocolo y el servicio, más un doble en memoria para tests.
- `Models/Plant.swift` reescrito.

Copia de seguridad del `project.pbxproj` original en el directorio temporal de la sesión,
por si hay que volver atrás.

---

## 2. Verificación de las afirmaciones técnicas sobre Apple

El traspaso pedía explícitamente contrastar esto antes de comprometer la arquitectura.
Fui a las sesiones de la WWDC26 de Apple, no a prensa secundaria.

### Confirmado, y mejor de lo que decía el reporte

| Afirmación | Veredicto |
|---|---|
| Protocolo `LanguageModel` para intercambiar modelos | **Confirmado por Apple.** El reporte lo daba por probable y `mygarden-f9` lo marcó como prensa secundaria. Es real: Anthropic y Google publican paquetes de Swift que conforman a él |
| `PrivateCloudComputeLanguageModel`, 32.000 tokens | Confirmado |
| Sin cuenta, sin autenticación, sin claves para PCC | Confirmado |
| Visión on-device | Confirmado, **iOS 27** |
| Generación guiada con `@Generable` | Confirmado, disponible desde iOS 26 |

### Corregido respecto al reporte

| El reporte dice | Lo correcto |
|---|---|
| Niveles de razonamiento `.light` y `.deep` | Son **tres**: `.light`, `.moderate`, `.deep` |
| Contexto on-device sin especificar | **8.192 tokens** en dispositivos recientes, 4.096 en la versión 26.0. Las APIs para inspeccionar el contexto y contar tokens llegaron en **iOS 26.4** |
| Tramo gratuito de PCC por estar en el Small Business Program | Es real y lo dice Apple, pero con dos condiciones que el reporte omite: hay **límite diario por usuario** (mayor si el usuario tiene iCloud+), y **hay que solicitarlo** en la web de desarrollador, no es automático |

El matiz del contexto importa de verdad: el JSON que produce `Prompts.buildWateringContext`
es grande. Cabe en 8.192 tokens, pero no cabe cómodamente en 4.096. Hay que medirlo con las
APIs de conteo de iOS 26.4 y recortar el contexto cuando no quepa, en vez de descubrirlo
en producción con un error.

---

## 3. El hallazgo: la promesa central no se cumple en todos los dispositivos

Este es el resultado más importante del análisis, y no está contemplado en ninguno de los
dos documentos.

**Foundation Models exige Apple Intelligence, que exige un chip A17 Pro o superior.** En
iPhone eso significa **iPhone 15 Pro en adelante**. El iPhone 15 y el 15 Plus, que salieron
el mismo año, **no lo tienen**, porque llevan A16.

El objetivo mínimo del proyecto es **iOS 26**, que se instala en iPhone 11 y posteriores.

De ahí sale el hueco: hay un tramo grande de dispositivos donde la app **se instala y
arranca, pero el motor de IA no existe**. `SystemLanguageModel` devuelve no disponible, y
Private Cloud Compute tampoco es salida, porque también exige dispositivo con Apple
Intelligence.

En esos iPhone, tal como está diseñada hoy, se caen las tres cosas:

- el ajuste de riego diario,
- el chat anclado (M04),
- la explicación del diagnóstico (M09).

Es decir, **se cae exactamente lo que el reporte pone como razón de ser del rediseño**: que
la app funcione completa el primer minuto sin pedirle nada al usuario. Hoy esa promesa solo
es cierta en iPhone 15 Pro y posteriores. En un iPhone 13 el rediseño entrega una app más
vacía que la vieja, porque la vieja al menos tenía la clave de Groq incrustada.

### La solución, acordada con la sesión de diseño

`mygarden-f9` reconoció el fallo como suyo y aportó una corrección importante a mi
propuesta. Lo que sigue es el diseño acordado, que es mejor que el que yo planteé.

Un dato que lo vuelve urgente: en los bloqueantes de pre-producción del proyecto viejo,
El usuario tenía anotado *"optimización de rendimiento, miniaturas y compresión para iPhone 11"*.
O sea que **el iPhone 11 está en su radar**, probablemente porque es suyo o de alguien
cercano. En ese teléfono, el rediseño tal como estaba escrito no tendría IA en absoluto.

#### Un balance de agua, no una bolsa de condicionales

El motor determinista no se monta como una ristra de `if`, porque eso se vuelve
inmantenible y no se puede razonar sobre ello. Se monta como un **balance hídrico**, que es
como funciona la agronomía de verdad:

| Término | De dónde sale |
|---|---|
| **Reserva** | Volumen de sustrato: diámetro y profundidad de la maceta, tipo de tierra |
| **Salida** | Evapotranspiración. Con lo que da WeatherKit se estima ET0 por **Hargreaves**, que solo necesita temperatura máxima, mínima y radiación extraterrestre (calculable con latitud y día del año). No hace falta Penman-Monteith |
| **Coeficiente de planta (Kc)** | **El grupo funcional que ya definimos para M07 es el Kc.** Suculenta, tropical de interior, aromática, arbusto de exterior. Para plantas identificadas, Trefle afina el número con tolerancia a sequía y humedad de sustrato objetivo |
| **Entradas** | Riegos registrados y lluvia real |
| **Modificador de exposición** | Terracota evapora más que plástico, interior o exterior, sol directo o luz indirecta |

La pieza elegante es el Kc: **la decisión que tomamos para las plantas no reconocidas (M07)
nos regala el parámetro que necesita el motor de reglas**. No es una coincidencia, es que
el grupo funcional predice el riego mejor que la especie, que era justo el argumento de P12.

#### Quién manda: las reglas siempre, el modelo encima

Aquí está la corrección de `mygarden-f9` a mi propuesta, y es la que evita un problema
serio. Yo había escrito que el LLM "matiza" el número. Si el modelo puede moverlo
libremente, **la misma planta con el mismo clima recibe un calendario distinto en un
iPhone 11 y en un iPhone 17**. El consejo de riego pasaría a depender del hardware del
usuario, que es indefendible.

El reparto correcto:

1. **Las reglas producen siempre el número.** En todos los dispositivos, sin excepción.
2. **El modelo, cuando existe, aporta dos cosas:** la explicación en lenguaje humano, y una
   corrección **acotada a más menos 2 días** que solo se aplica si declara confianza alta y
   da un motivo, típicamente algo que ve en las fotos y que las reglas no pueden ver: una
   hoja caída, tierra con moho, un tallo blando.
3. **La auditoría separa lo calculado de lo inferido:** *"Reglas: cada 5 días. La IA lo bajó
   a 4 porque ve la tierra todavía húmeda en tu última foto."*

Así la app se comporta igual en todos los dispositivos y el modelo es **aditivo**, no
determinante. Y de paso el M03 queda más honesto de lo que estaba diseñado, porque distingue
lo que se calculó de lo que se infirió.

#### Degradar, ni ocultar ni dar una mala noticia

Yo proponía mostrar el botón con una explicación honesta. `mygarden-f9` señaló que un botón
que solo sirve para dar malas noticias es casi tan malo como esconderlo, y tiene razón.

La observación que lo resuelve: **el panel de 6 fuentes del M04 es contenido estático**.
PlantNet, Trefle, WeatherKit, el historial de riego, las fotos y lo que escribió el usuario
existen en cualquier iPhone. Lo único que necesita el modelo es la conversación.

| Pantalla | Sin Apple Intelligence |
|---|---|
| **M04 Chat** | El botón abre el panel de fuentes como **ficha de datos consultable**, con una nota arriba: "Tu iPhone no puede hacer preguntas en lenguaje natural, pero aquí tienes todo lo que sé de esta planta". La clave propia, debajo. Se pierde la conversación, no la información |
| **M09 Salud** | PlantNet detecta enfermedades desde su API y funciona en cualquier dispositivo. Se muestra "PlantNet detectó mildiu con 78% de confianza" más recomendaciones plantilladas por tipo de patología. Se degrada, no desaparece |
| **M03 Ficha** | La tarjeta de IA necesita variante determinista. **La plantilla se escribe primero y el modelo la reescribe cuando está, no al revés** |

#### El mensaje de Ajustes necesita tres variantes, no dos

Esto es fácil de pasar por alto y produce el peor mensaje posible: mandar a alguien a
activar una función que su teléfono no tiene. `SystemLanguageModel` distingue casos que
exigen respuestas distintas:

| Caso | Qué decir |
|---|---|
| Dispositivo no elegible (iPhone 11) | **No mandarle a activar nada.** Ofrecerle la clave propia |
| Apple Intelligence desactivada por el usuario | Ahí sí: explicarle cómo activarla en Ajustes del sistema |
| Modelo descargándose | Estado temporal, decirlo y ya |

#### Queda un cabo suelto

El tramo gratuito de PCC tiene **límite diario por usuario**. Si el chat es la función que
más lo consume, hay que decidir qué pasa cuando se agota. Ahí también hace falta degradación:
lo natural es caer al modelo on-device, que es exactamente el respaldo que el reporte ya
preveía.

La caída debe ser **silenciosa en la interfaz pero explícita en el registro**. En el ajuste
de riego el usuario no necesita enterarse; en el chat sí, porque nota el cambio de calidad
de la respuesta y merece saber por qué. Pero `AIAuditEntry` anota **siempre** qué motor
respondió de verdad. Si dentro de tres meses un ajuste sale raro, poder decir "ese día
respondieron las reglas solas porque se agotó la cuota" es toda la diferencia.

---

## 4. Decisiones cerradas con la sesión de diseño

Consulté a `mygarden-f9` en tres tandas. Marco el origen de cada decisión, porque no todas
tienen el mismo peso: una cosa es lo que el usuario dijo y otra lo que dedujimos entre las dos
sesiones.

**Leyenda de origen:** `[USUARIO]` lo dijo él · `[MAQUETA]` está en las 11 pantallas que aprobó
viéndolas correr · `[INFERIDO]` lo dedujimos `mygarden-f9` y yo.

| # | Decisión | Origen | Coste de revertir |
|---|---|---|---|
| 1 | Etapas de crecimiento en el esquema desde el principio, forma mínima | `[INFERIDO]` | Alto si no se hace ahora, nulo si se hace |
| 2 | WeatherKit directo, sin pasar por `WeatherAPIService` | `[USUARIO]` eliminar claves | Medio |
| 3 | Bundle `com.ipo.newGardenNew`, identificador de CloudKit en una sola constante | `[INFERIDO]` | Bajo, por diseño |
| 4 | Swift 6.2 con aislamiento `MainActor` por defecto | `[INFERIDO]` | Bajo |
| 5 | **Fuera Sign in with Apple.** CloudKit se queda | `[INFERIDO]` + `[MAQUETA]` M10 no tiene sección de cuenta | Bajo |
| 6 | Tutorial conservado pero **no obligatorio**, accesible desde Ajustes | `[MAQUETA]` M10 tiene "Ver el tutorial" | Bajo |
| 7 | `GardenTab` y `GardenNode`: portar modelos, **ninguna vista** | `[USUARIO]` escribió "el código se conserva para uso futuro" al desactivar la pestaña | Bajo |
| 8 | Partir `AIAnalysis` en 4 modelos | `[INFERIDO]` | **Alto** una vez haya datos |
| 9 | `String(localized:)` con español literal, catálogo poblado solo | `[INFERIDO]` | Bajo |
| 10 | Notificaciones: **un resumen diario**, no dos por planta | `[INFERIDO]` + `[MAQUETA]` M10 dice "Hora preferida 09:00" | Bajo |
| 11 | Excepción de germinación: 2 avisos al día durante esa etapa | `[MAQUETA]` M08 lo dice literal | Bajo |
| 12 | Racha fuera, sustituida por salud del jardín | `[INFERIDO]`, no aparece en ninguna maqueta | Bajo |
| 13 | Pestaña Salud separada | `[USUARIO]` vio M09 y no quiso fusionarla | Bajo |
| 14 | "Todo en orden" plegado recordando el estado | `[INFERIDO]` | Bajo |

### Las tres que conviene entender, no solo aprobar

**Por qué se va Sign in with Apple (decisión 5).** No es una decisión estética. La
sincronización de SwiftData con CloudKit funciona con la **cuenta de iCloud del
dispositivo**, no con Sign in with Apple. En la app vieja, iniciar sesión no habilita
ninguna sincronización: lo único que hace es guardar nombre y correo en `UserDefaults` y
poner una bandera a `true`. Es un muro antes del valor que no habilita ninguna función.
Si algún día hay jardines compartidos entre personas, ahí sí hará falta identidad.

**Por qué hay que partir `AIAnalysis` (decisión 8).** No es purismo. Está a la vista en el
código, en la función que lee el último chequeo de salud:

```swift
if let score = health.plantProfile { healthData["health_score"] = score }
if let confidence = health.confidence { healthData["health_status"] = confidence }
```

Un campo llamado "perfil de la planta" contiene un número del 1 al 10, y uno llamado
"confianza" contiene un estado de salud. Eso ya es deuda hoy. Con el chat anclado y la
auditoría de fuentes que pide P4, se vuelve insostenible. Y es esquema, o sea que arreglarlo
después de que haya datos sincronizados cuesta una migración.

**Por qué cambian las notificaciones (decisión 10).** Dos razones técnicas que fuerzan la
mano, aportadas por `mygarden-f9`:

- iOS limita a **64 notificaciones pendientes por app**. Con dos por planta, la app deja de
  programar avisos a partir de 32 plantas. No falla con error: falla en silencio.
- `UNTimeIntervalNotificationTrigger` dispara cuando cae el intervalo, no a una hora
  civilizada. Si el usuario regó a las 23:40, el aviso ámbar le llega de madrugada.

Un resumen diario a la hora que el usuario elija resuelve los dos y no escala con el número
de plantas. Lo que se pierde es el aviso en el instante exacto del vencimiento, que nadie
necesita porque nadie riega a las 3 de la mañana.

### Detalle que no se puede perder: la instantánea de las fuentes

`ChatMessage` tiene que guardar una **copia del valor** de cada fuente citada, no una
referencia. El clima cambia cada hora. Si dentro de un mes el usuario relee la conversación
y el chip dice "WeatherKit: 32 grados", eso tiene que seguir siendo lo que la IA vio ese
día, no lo que hace ahora. Si se guarda el puntero, las citas mienten con el tiempo, y todo
el diseño del M04 se apoya en que no mientan.

### Detalle que no se puede perder: la seguridad para mascotas

Es un requisito duro del usuario, no una función más. Hoy depende de una clave de `UserDefaults`
sin tipar llamada `"hasPets"`. Un error de tipeo en esa cadena desactiva los avisos de
toxicidad **en silencio**, que es el peor fallo posible en esta app.

En la implementación pasa a ser un tipo cerrado que no admite estados a medias, y un valor
`nil` de toxicidad (todavía no se sabe) **nunca** se pinta como "es segura".

---

## 5. Arquitectura objetivo

```
newGardenNew/
├── App/              Punto de entrada, contenedor dual, inyección, 4 pestañas
├── Core/             Logging, Keychain, extensiones, AppSettings unificado
├── Models/           12 modelos SwiftData + los enums tipados
├── Repositories/     5 repositorios con errores que se propagan
├── Services/
│   ├── AI/           AIEngine (protocolo), enrutador, Foundation Models, clave opcional
│   ├── Watering/     Motor de reglas, orquestador, etapas, tarea de fondo
│   ├── PlantData/    PlantNet, Trefle
│   ├── Weather/      Protocolo, WeatherKit, caché, ubicación
│   ├── Notifications/ Resumen diario + germinación
│   └── Images/       Caché de miniaturas
├── Features/         Una carpeta por pantalla: vista + ViewModel
├── DesignSystem/     Ya existe
└── Mockups/          Se conservan como referencia viva contra la que comparar

newGardenNewWidget/   Target nuevo: widget + App Intents
```

Regla que se aplica en todas partes: los ViewModels **reciben** los servicios por protocolo,
nunca los instancian. Eso es lo que hoy no se cumple en el proyecto viejo, donde la
inyección existe en la forma pero no en el fondo.

---

## 6. Inventario de trabajo

### Se porta casi tal cual (lógica que vale y funciona)

| Qué | Retoque |
|---|---|
| `Prompts.buildWateringContext` | **Íntegro.** Se conservan los nombres de campo del JSON, porque cambiarlos es cambiar el prompt sin darse cuenta |
| `PlantNetService` y sus modelos | Quitar los `print`, clave embebida en vez de pedida |
| `TrefleService` | Degradación elegante sin token |
| `WeatherCache` | Actor con TTL, pasa a guardar modelos neutros |
| `KeychainService` | Hecho |
| Repositorios | Errores que se propagan de verdad |
| Configuración dual de `ModelContainer` | Con el identificador de contenedor extraído a una constante |

### Se reescribe

| Qué | Por qué |
|---|---|
| `AIServiceFactory` | Sustituido por enrutado por tarea (el error de diseño del reporte) |
| `BackgroundAnalysisScheduler` | Creaba **su propio** `ModelContainer` sin las configuraciones de la app, o sea que escribía en otra base de datos. Además recorría todas las plantas en secuencia dentro de un presupuesto de 30 segundos |
| Los 20 accesos sueltos a `UserDefaults` | Unificados en `AppSettings` |
| Los 59 `print()` | `os.Logger` con categorías, hecho |
| Los 10 `try? context.save()` | Errores propagados |
| `PlantImageView` | Con caché, hoy decodifica en cada renderizado |
| Toda la capa de vistas | Es el rediseño |

### No se porta

| Qué | Por qué |
|---|---|
| `GroqService` | Clave de API escrita en el código fuente. Groq desaparece del diseño |
| `AppState` con autenticación | Decisión 5 |
| `WeatherAPIService` | Sustituido por WeatherKit |

### Nuevo

Motor de reglas de riego, enrutador de IA con registro de auditoría, etapas de crecimiento y
sus transiciones, alta por grupo funcional (M07), siembra por etapas (M08), chat anclado
(M04), widget con App Intents (M11), caché de imágenes, notificaciones replanteadas.

---

## 7. Lo que necesito del usuario

Cinco cosas que **yo no puedo hacer**, todas en tu cuenta de desarrollador o en cuentas de
terceros. Ninguna bloquea que empiece: bloquean que la app funcione de verdad en el
dispositivo.

### Urgente, independiente de este proyecto

**1. Rota la clave de Groq.** Está escrita en `GroqService.swift:12` del proyecto viejo, y
**también en el historial de git**, así que borrar la línea no la borra. Hay que invalidarla
en tu cuenta de Groq. Es obligatorio aunque esa app no se publique nunca.

### Para que funcione en dispositivo

**2. WeatherKit.** Activar la capability en el App ID dentro del portal de desarrollador.
Incluye 500.000 llamadas al mes con la membresía del Programa de Desarrolladores, que sobra
de largo para esto. Además obliga a mostrar el logo de Apple Weather y el enlace legal a las
fuentes de datos: le reservo sitio en el diseño desde el principio en vez de encajarlo al
final.

**3. Clave de PlantNet bajo el plan sin ánimo de lucro.** El diseño la lleva embebida en vez
de pedírsela al usuario. Necesito la clave, y la atribución "Powered by Pl@ntNet" también es
obligatoria (ya está puesta en el pie de M10).

**4. Private Cloud Compute.** Hay que **solicitarlo** en la web de desarrollador, no viene
solo por estar en el Small Business Program. No corre prisa: solo afecta al chat y al
diagnóstico, y solo en iOS 27.

### Decisión tuya

**5. ¿Conservas tus plantas actuales o empezamos de cero?** Tus datos reales viven en el
contenedor de CloudKit del proyecto viejo. Reutilizar ese contenedor conserva tus plantas,
tus fotos y tu historial, pero ata el proyecto nuevo al esquema del viejo. Empezar limpio es
más ordenado y pierdes los datos. Dejo el identificador en una sola constante para que
cambiarlo sea una línea, pero dime qué prefieres.

---

## 8. Preguntas abiertas que te dejo apuntadas

Tres cosas que `mygarden-f9` y yo decidimos por defecto para no pararnos, y que quiero que
mires cuando validemos:

1. **¿La app tiene que estar en inglés además de español?** Monto el catálogo desde el
   principio, así que traducir después es rellenarlo sin tocar código. Pero si el inglés se
   queda, hace falta decidir si vuelve el selector de idioma a Ajustes (M10 lo quitó al bajar
   de 10 secciones a 4) o si la app sigue el idioma del sistema sin selector, que es lo que
   hace la mayoría y lo que recomendamos.

2. **El widget necesita un target nuevo en Xcode.** Crear un target a mano editando el
   `project.pbxproj` es delicado, y es justo la operación que dejó el proyecto viejo sin
   compilar en su momento (sección 14 del reporte). **Mi recomendación: créalo tú desde
   Xcode**, que son dos clics (File, New, Target, Widget Extension), y yo escribo todo el
   código dentro. Si prefieres que lo haga yo, lo hago, con copia de seguridad previa.

3. **Las miniaturas son degradados, no fotos.** Cuando entren fotos reales, las
   composiciones van a cambiar de aspecto, sobre todo la cuadrícula de M02 y el hero de M03.
   Lo construyo con fotos reales desde el principio y dejo el degradado solo como respaldo
   cuando una planta no tenga foto.

---

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Foundation Models ausente en buena parte del parque | Motor de reglas determinista como suelo. **Es el cambio de alcance de este análisis** |
| El contexto del prompt no cabe en 8.192 tokens | Medir con las APIs de conteo de iOS 26.4 y recortar por prioridad, no truncar a ciegas |
| Crear el target del widget a mano rompe el proyecto | Que lo cree el usuario en Xcode, o copia de seguridad y verificación de build |
| El esquema de SwiftData se fija ahora y CloudKit lo despliega | Por eso las etapas, los 4 modelos de IA y los dos de jardín entran ya, aunque algunos no se usen hasta el final |
| Desviarme de las maquetas aprobadas | Las maquetas se quedan en el proyecto. Comparo pantalla contra maqueta en el plan de validación |

---

## 10. Después: el plan de validación

Cuando la implementación esté terminada, el plan de checkpoints no va por fases técnicas
sino **por pantalla contra su maqueta**, que es el contrato. Un checkpoint por pantalla, más
los transversales:

M01 Hoy · M02 Plantas · M03 Ficha · M04 Chat · M05 y M06 Alta · M07 No reconocida ·
M08 Siembra · M09 Salud · M10 Ajustes · M11 Widget

Transversales: modo oscuro, Dynamic Type en tamaños de accesibilidad, VoiceOver, seguridad
para mascotas de punta a punta, comportamiento en un iPhone sin Apple Intelligence, y
sincronización con CloudKit.

En cada uno: qué mirar, cómo probarlo, y qué decisión reversible hay detrás por si quieres
cambiarla.
