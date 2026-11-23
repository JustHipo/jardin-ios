# Plan de validación

**Para:** el usuario
**Cuándo usarlo:** ahora, al volver. Es el punto de partida para revisar todo lo construido.

Este documento reemplaza el trabajo por fases con checkpoint: como pediste, construí la
app entera de una pasada y ahora la revisamos módulo por módulo, comparando cada pantalla
contra su maqueta aprobada. Cada checkpoint dice qué mirar, cómo probarlo, y qué decisión
reversible hay detrás si quieres cambiarla.

**Antes de empezar:**

```bash
cd ~/proyectos/newGardenNew/newGardenNew
xcodebuild -project newGardenNew.xcodeproj -scheme newGardenNew \
  -destination 'platform=iOS Simulator,name=MyGarden 17 Pro' -configuration Debug build
```

Compila limpio. Los 14 tests unitarios pasan (`xcodebuild test` con el mismo destino).

---

## Cómo usar esto

Para cada módulo: instala la app, sigue los pasos de "cómo probarlo", y decide
**Aprobado**, **Ajustar** (dime qué) o **Revertir** (vuelvo al criterio anterior). Las
maquetas siguen en `Mockups/Screens/` para comparar lado a lado en el canvas de Xcode.

Instalar y lanzar de un tirón:

```bash
xcrun simctl install "MyGarden 17 Pro" \
  ~/Library/Developer/Xcode/DerivedData/newGardenNew-*/Build/Products/Debug-iphonesimulator/newGardenNew.app
xcrun simctl launch "MyGarden 17 Pro" com.ipo.newGardenNew
```

---

## Decisión previa a todos los módulos

Antes de entrar pantalla por pantalla, dos cosas que afectan a todas y que no contestaste
del todo cuando te pregunté:

1. **Confirmaste no importar tus plantas actuales.** El contenedor de CloudKit es nuevo
   (`iCloud.com.ipo.newGardenNew`), separado del proyecto viejo. Registrado.
2. **Solo español, sin selector de idioma en Ajustes.** Elegiste esta opción. El código usa
   `String(localized:defaultValue:)` en casi todo el texto, así que el inglés queda a un
   `.xcstrings` de distancia si cambias de opinión más adelante.

---

## M01. Hoy

**Qué mirar:** que la jerarquía sea agenda, no inventario. Hoy vencidas arriba, esta semana
después, todo en orden plegado abajo.

**Cómo probarlo:**
1. Añade 2-3 plantas con fotos distintas desde el botón `+`
2. Verifica que aparecen en la sección correcta según cuándo las regaste
3. Toca la gota de una fila: debe registrar el riego al instante y mostrar "Deshacer" 5
   segundos, sin pedir confirmación antes
4. Toca "Deshacer" y confirma que el riego desaparece
5. Despliega "Todo en orden" y comprueba que recuerda el estado si sales y vuelves a entrar

**Decisiones reversibles detrás:**
- Un tap para regar con deshacer, en vez de confirmación previa (P3). Coste de revertir: bajo.
- "Todo en orden" plegado por defecto, recuerda el estado. `[INFERIDO]`. Coste: bajo.

**Encontrado en esta sesión:** funciona con datos reales, probado en vivo. Sin bugs
pendientes en este módulo.

---

## M02. Plantas

**Qué mirar:** la foto real ocupa el ancho de la tarjeta, no un círculo pequeño. Los filtros
por estado solo aparecen si hay al menos una planta en ese estado.

**Cómo probarlo:**
1. Con varias plantas, prueba los chips de filtro (Todas, Al día, Pronto, etc.)
2. Busca por nombre y por especie en la barra de búsqueda
3. Confirma que tocar una tarjeta abre la ficha correcta

**Decisión reversible:** ninguna nueva aquí, sigue el diseño de M02 tal cual.

---

## M03. Ficha de planta

**Qué mirar:** esta es la pantalla que más cambia respecto a la maqueta, porque ahí vive el
reparto de mando entre reglas e IA. Comprueba:

1. La tarjeta "Ajuste de riego" siempre muestra un número, incluso sin foto ni IA
   (viene del motor de reglas, nunca está vacía salvo la primera vez que abres la ficha)
2. Toca "Analizar ahora": debe aparecer un ciclo calculado (probé "cada 46 días" con una
   planta sin datos, la matemática es real, no inventada)
3. Si en algún momento el ajuste de IA se aplica, debe verse "Reglas: cada X días, la IA lo
   ajustó a Y" y los botones de mantener/revertir
4. La tarjeta de mascotas: si activas "Tengo mascotas" en Ajustes, y la planta no tiene
   toxicidad conocida, debe decir explícitamente "Todavía no sabemos" y **nunca** "es
   segura" por defecto

**Decisiones reversibles detrás:**
- `AIAnalysis` partido en 4 modelos (`AIAnalysis`, `HealthCheck`, `AIAuditEntry`,
  `ChatMessage`). `[INFERIDO]`, confirmado con evidencia en el código viejo. **Coste de
  revertir: alto**, ya con esquema desplegado. Si quieres cambiar algo de esto, es el
  momento.
- Las reglas producen siempre el número, la IA solo corrige ±2 días con motivo. Acordado
  con `mygarden-f9`, es el cambio de arquitectura más importante de toda la sesión.

**Pendiente de decidir:** el texto exacto de la plantilla determinista ("Cada X días,
calculado con el clima y la maceta de esta planta") es mío, no está en la maqueta. Dime si
quieres otra redacción.

---

## M04. Chat

**Qué mirar:** el panel de 6 fuentes arriba, plegable, y que la conversación cite de dónde
sale cada dato.

**Cómo probarlo:**
1. Abre "Preguntar" desde la ficha de una planta
2. Despliega el panel de fuentes y confirma que cuenta lo que sabe de esa planta
3. Escribe una pregunta y envíala

**Lo que vas a ver, y por qué:** en este Mac/simulador, el modelo on-device de Apple
Intelligence puede no estar descargado, así que la respuesta puede fallar con un mensaje
honesto ("No pude responder ahora") en vez de contestar. **Esto no es un bug**: lo probé en
vivo y confirmé por el log que es un error real de `ModelManagerServices` de Apple, no de mi
código. En tu iPhone real con Apple Intelligence activo debería responder de verdad.
Verifícalo ahí cuando puedas.

**Decisión reversible:** las citas de fuentes se guardan como instantánea (el valor de ese
momento, no una referencia), para que no mientan si el clima cambia después. Acordado con
`mygarden-f9`, coste de revertir: medio, una vez haya conversaciones guardadas.

---

## M05 y M06. Alta de planta (cámara y confirmar)

**Qué mirar:** dos pasos, no cinco. La app dispara la identificación en cuanto hay foto.

**Cómo probarlo:**
1. Toca `+`, elige una foto (el simulador usa la fototeca, no cámara real)
2. Debe navegar solo a "Confirmar" cuando termine de intentar identificar
3. Con la clave de PlantNet todavía sin poner, va a fallar con un mensaje honesto de "no
   encontré coincidencias claras", no con un error técnico
4. Elige dónde vive y guarda: debe volver limpio a donde estabas, sin hojas colgadas

**Encontrado y corregido en esta sesión:** dos bugs reales de navegación (ver
`docs/PROGRESO.md`, sección de hoy). Los descubrí probando la app de verdad, no leyendo el
código. Ya corregidos y reprobados.

**Pendiente de ti:** la clave real de PlantNet (sección 7 del análisis) para que la
identificación funcione de verdad en vez de degradarse.

---

## M07. Planta no reconocida

**Qué mirar:** que preguntar por el grupo funcional (suculenta, tropical, aromática...) en
vez de la especie.

**Cómo probarlo:**
1. Desde la cámara, menú `•••`, "No la reconoce, añadir a mano"
2. Completa nombre y grupo funcional, guarda
3. Confirma que la planta aparece en Plantas con badge "Sin registro" y sin especie

**Decisión reversible:** el grupo funcional que eliges aquí es literalmente el coeficiente
que usa el motor de reglas (`FunctionalGroup.cropCoefficient`). Si cambias los grupos o sus
valores, cambia el cálculo de riego de estas plantas. Coste de revertir: bajo, son solo
números en un enum.

---

## M08. Sembrar semillas

**Qué mirar:** esta es la pantalla que menos se parece a algo que ya exista. La sesión de
diseño se cerró antes de que pudiéramos discutir los detalles finos, así que lo que ves
aquí son **mis decisiones por defecto**, no algo acordado contigo o con `mygarden-f9`.

**Cómo probarlo:**
1. Desde la cámara, menú `•••`, "Estoy sembrando semillas"
2. Rellena qué sembraste, método y fecha, mira el plan de 4 etapas
3. Guarda y confirma en Plantas que aparece con `growthStage = .sowing`

**Decisiones que tomé y que quiero que revises específicamente:**
- Los intervalos de riego por etapa (siembra 24h, germinación 12h, plántula 48h,
  trasplante 72h) son los que aparecían en la maqueta, los codifiqué tal cual
- La transición automática entre etapas **no está implementada todavía**: hoy la etapa se
  fija al crear la planta y no avanza sola. Falta decidir si avanza por fecha, por lo que
  el usuario marque a mano, o por lo que la app vea en fotos nuevas
- Las notificaciones de germinación (2 al día) están escritas en
  `NotificationScheduler.scheduleGermination`, pero **nadie las dispara todavía**: falta
  conectarlas a la transición de etapa de arriba

**Esto es lo más incompleto de toda la implementación.** Trátalo como un borrador de
trabajo, no como terminado.

---

## M09. Salud

**Qué mirar:** funciona en cualquier dispositivo, con o sin IA (P4, degradación).

**Cómo probarlo:**
1. Con al menos una planta guardada, ve a Salud
2. Confirma que "Diagnosticar" está deshabilitado sin plantas y habilitado con al menos una
   (lo probé en vivo, cambia solo)
3. Toma una foto: debe intentar PlantNet, y narrar el diagnóstico con IA si está disponible,
   o con recomendaciones plantilladas si no

**Decisión reversible:** las recomendaciones plantilladas (aislar, reducir riego, refotografiar)
son genéricas, no específicas por enfermedad. Coste de revertir: bajo.

---

## M10. Ajustes

**Qué mirar:** de 10 secciones a 4, sin ninguna clave obligatoria. El mensaje de "IA en tu
iPhone" es distinto según el estado real del dispositivo.

**Cómo probarlo:**
1. Confirma que dice "Activa, gratis y sin conexión" si `SystemLanguageModel` está
   disponible (en este Mac lo estaba)
2. Activa "Tengo mascotas" y confirma que aparece el selector de tipo
3. Activa/desactiva avisos y cambia la hora preferida
4. Abre "IA avanzada" y prueba a guardar una clave (se guarda en el Llavero, lo confirmé
   leyendo el código, no hay UI para probarlo sin una clave real)

**Encontrado en esta sesión:** funciona en vivo, capturas en la conversación.

**Pendiente de decidir:** el tutorial de M10 lleva a un placeholder (`Text("Tutorial")`).
Las 6 tarjetas del tutorial viejo describen pantallas que ya no existen (pestaña Jardín,
sub-pestañas del detalle), así que hay que reescribirlas, no solo copiarlas.

---

## M11. Widget

**No construido.** Decidiste crear el target tú mismo en Xcode (File, New, Target, Widget
Extension) porque editar el `project.pbxproj` a mano es la operación que dejó el proyecto
viejo sin compilar una vez. En cuanto exista el target, el código que falta es acotado:

- Un `AppIntent` de "Regar [planta]", compartido entre el widget, Siri y Atajos
- Un `TimelineProvider` que lea las plantas vencidas vía el mismo `PlantRepository`
- Las tres vistas del widget (mediano, pequeño, pantalla de bloqueo), que puedo calcar de
  `Mockups/Screens/M11_WidgetMockup.swift` casi tal cual

Dime cuándo crees el target y lo completo.

---

## Transversales

Cosas que cruzan todas las pantallas, para revisar una vez y no por módulo:

| Qué | Estado |
|---|---|
| Modo oscuro | No verificado en esta sesión. Los colores salen del catálogo de assets con variantes, debería funcionar, pero no lo comprobé en vivo |
| Dynamic Type en tamaños de accesibilidad | No verificado |
| VoiceOver | Los componentes (`DSStatusBadge`, `DSConfidenceRow`, etc.) llevan `accessibilityLabel`, pero no lo probé con VoiceOver activado de verdad |
| Seguridad para mascotas de punta a punta | Verificado el tipo (`PetSafetyVerdict` nunca colapsa "desconocido" en "seguro"), no verificado con una planta tóxica real de punta a punta |
| Sincronización con CloudKit | No verificable sin cuenta de iCloud activa en el simulador. Verifica en un dispositivo real con tu Apple ID |
| Comportamiento en iPhone sin Apple Intelligence | Verificado el camino de error (ver M04), no verificado en un iPhone real sin Apple Intelligence |

---

## Los 5 pendientes que ya conocías, resumidos aquí también

1. Rotar la clave de Groq del proyecto viejo (urgente, independiente de esto)
2. Activar la capability de WeatherKit en el App ID
3. Conseguir la clave de PlantNet bajo el plan sin ánimo de lucro
4. Solicitar Private Cloud Compute en la web de desarrollador
5. Crear el target del widget en Xcode (M11 arriba)

Sin el 2 y el 3, el clima y la identificación de especies siguen degradados a "sin datos"
o "no reconocida", que es justo el comportamiento que la app debe tener sin ellas: no falla,
funciona con menos precisión.
