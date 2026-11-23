# Baseline del algoritmo de riego: antes y después de las 3 mejoras

Registro de la verificación hecha antes y después de implementar las tres mejoras acordadas
(cross-check con Open-Meteo, tip de drenaje, calibración por comportamiento real), con los
valores reales capturados en cada paso. Complementa
[ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md](ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md).

**Fecha:** 19 de septiembre de 2026.

---

## 0. Estado de partida: la suite de tests estaba rota

Antes de tocar nada, `test_sim` falló con 12 errores de compilación: `WateringRuleEngine.Input`
había ganado dos parámetros (`containerPlantCount`, `healthStressModifier`) en algún commit
anterior sin que `WateringRuleEngineTests.swift` se actualizara. Nadie lo había notado porque
`build_sim` (compilar la app) pasa igual; solo `test_sim` (compilar y correr los tests) lo
expone. Se arregló con un `init` explícito en `Input` que da a esos dos campos su valor neutro
por defecto (`nil` y `1.0`), sin tocar los 12 call sites de test ni cambiar ningún resultado.

**Antes:** 12 errores de compilación, 0 tests corriendo.
**Después del fix:** 17/17 tests pasando. Esta es la base real sobre la que se compara todo lo
demás, no una app hipotéticamente sana.

---

## 1. Instrumentación del motor de reglas

`WateringRuleEngine.Output` solo exponía `cycleDays` y un campo `et0MmPerDay` que, pese al
nombre, en realidad contenía `dailyLossMm` (ET0 ya multiplicado por Kc y los modificadores) —
un error de nombre que hacía imposible comparar el ET0 real contra una referencia externa. Se
amplió `Output` para exponer cada término intermedio por separado (ET0 puro, pérdida diaria,
cada modificador, reserva, lluvia, reserva efectiva, días sin redondear) y se corrigió el
nombre. El log de checkpoint del orquestador ahora imprime la cadena completa de cálculo en una
sola línea, útil para explicar cualquier número futuro sin volver a leer el código.

Esto no cambia ningún resultado, solo lo hace visible.

---

## 2. El motor determinista: matriz de escenarios (sin cambios de comportamiento)

Corrida directamente contra el código real del motor (`WateringRuleEngine.swift` y
`WateringCalibration.swift`, compilados como script standalone con `swiftc`, sin simulador,
para tener un número exacto y reproducible fuera de cualquier variable de entorno de Xcode).

| Escenario | ET0 (mm/día) | Pérdida diaria (mm/día) | Exposición | Material | Reserva (mm) | Lluvia (mm) | Reserva efectiva (mm) | Días sin redondear | Ciclo (días) |
|---|---|---|---|---|---|---|---|---|---|
| Default, sin datos | 2.50 | 1.75 | 1.00 | 1.00 | 39.6 | 0.0 | 39.6 | 22.6 | 23 |
| Suculenta, maceta chica terracota, sol pleno | 2.50 | 1.62 | 1.30 | 1.25 | 26.4 | 0.0 | 26.4 | 16.2 | 16 |
| Tropical interior, maceta grande plástico, luz indirecta | 2.50 | 1.72 | 0.85 | 0.90 | 66.0 | 0.0 | 66.0 | 38.3 | 38 |
| 3 plantas en la misma maceta | 2.50 | 2.25 | 1.00 | 0.90 | 44.0 | 0.0 | 14.7 | 6.5 | 7 |
| Estrés hídrico visible (sequía detectada) | 2.50 | 2.34 | 1.00 | 0.90 | 44.0 | 0.0 | 44.0 | 18.8 | 19 |
| Exceso de riego detectado | 2.50 | 1.35 | 1.00 | 0.90 | 44.0 | 0.0 | 44.0 | 32.6 | 33 |
| Clima cálido y seco (32°C, 30% humedad) | 7.60 | 7.11 | 1.30 | 0.90 | 44.0 | 0.0 | 44.0 | 6.2 | 6 |
| Mismo clima cálido, con lluvia reciente y pronosticada | 7.60 | 7.11 | 1.30 | 0.90 | 44.0 | 30.0 | 59.0 | 8.3 | 8 |
| Maceta muy chica (10cm) | 2.50 | 1.57 | 1.00 | 0.90 | 22.0 | 0.0 | 22.0 | 14.0 | 14 |

**Estos números son idénticos antes y después de las 3 mejoras.** Ninguna de las tres toca la
matemática de `computeCycle`: el cross-check de Open-Meteo es solo un log paralelo, el tip de
drenaje es solo texto, y la calibración se aplica DESPUÉS de este cálculo, como una capa
separada (sección 4). Esto es intencional: el motor base no cambia, solo se le agrega
instrumentación e información adicional en capas explícitas y auditables.

---

## 3. El hallazgo real: cross-check contra Open-Meteo en vivo

Se tomaron los datos reales de Open-Meteo para Santiago (2026-09-19: temperatura máx 19.6°C,
mín 12.0°C, humedad media 71%, viento máx 6.6 km/h, nubosidad media 70%, elevación real 554m)
y se corrieron por la fórmula de `estimateET0` con esos mismos valores de entrada.

| Fuente | ET0 (mm/día) |
|---|---|
| Open-Meteo (`et0_fao_evapotranspiration`, valor real de referencia) | **1.76** |
| Nuestra implementación de Penman-Monteith, mismos datos de entrada | **2.43** |
| Diferencia | **+38%** |

Esto es exactamente lo que el cross-check está diseñado para encontrar, y lo encontró en la
primera comparación real. Hipótesis de causa más probable, sin haber aún aislado la variable:

1. **La radiación solar es la sospechosa principal.** El código estima la radiación de onda
   corta a partir de la nubosidad reportada (`sunshineFraction = 1 - cloudPct/100`), una
   sustitución conocida por ser imprecisa: la relación entre "% de cielo nublado" y "fracción
   real de horas de sol" no es lineal, y Open-Meteo probablemente usa datos de radiación real
   (satelital/reanálisis) en vez de esta aproximación.
2. **Elevación:** el código asume nivel del mar (0m) por diseño; el lugar real está a 554m.
   Efecto esperado menor que el de la radiación, pero no nulo.
3. **Altura de medición del viento:** Open-Meteo reporta el viento a 10m (`wind_speed_10m_max`,
   además como máximo del día, no promedio); el código lo trata como si ya fuera el estándar
   FAO-56 a 2m, sin corrección de perfil logarítmico. Confunde una velocidad más alta y de pico
   con la velocidad media a 2m, lo que puede inflar el término aerodinámico.

**No se corrigió el código por esto todavía** — es una sola comparación, un solo día, y
conviene juntar más días antes de tocar una fórmula que ya tuvo un bug de magnitud (la reserva
por diámetro). El valor de esta mejora es exactamente este: ahora el log de cada análisis real
va a acumular estas comparaciones automáticamente, así que en unas semanas de uso real va a
haber suficiente señal para saber si esto es un sesgo sistemático (y de qué tamaño) o ruido de
un solo día atípico.

---

## 4. La capa de calibración: ejemplos reales

Corridos directamente contra `WateringCalibration.updatedMultiplier` y `.applyMultiplier`:

| Caso | Multiplicador antes | Multiplicador después | Ciclo de 10 días pasaría a |
|---|---|---|---|
| Riega justo a tiempo | 1.000 | 1.000 | 10 días (sin cambio) |
| Riega bastante antes (5 de 10 días) | 1.000 | 0.875 | 9 días |
| Riega bastante después (20 de 10 días) | 1.000 | 1.250 | 13 días |
| Ya calibrado a 0.8, riega a tiempo otra vez | 0.800 | 0.800 | 8 días |

Nótese que un solo riego temprano no colapsa el ciclo a la mitad (5 días): el suavizado
(peso 0.25 para la observación nueva) lo mueve solo una fracción del camino, tal como se
concluyó en la sección 11 del documento de análisis: un evento raro no debe sobreescribir
meses de señal previa.

---

## 5. Un bug real encontrado al escribir los tests (no antes, no después: durante)

Al escribir el test de integración del repositorio (`WateringEventRepositoryCalibrationTests`),
la primera versión falló: el multiplicador se quedaba en 1.0 cuando debía bajar. La causa es un
comportamiento real de SwiftData, no una falla de lógica de calibración: al construir
`WateringEvent(wateredAt:, plant:)`, asignar `plant:` ya conecta el nuevo evento al grafo de
relaciones de un `Plant` que SwiftData ya está siguiendo, así que una consulta hecha ANTES del
`modelContext.insert(event)` explícito podía encontrar el evento nuevo a sí mismo como si fuera
"el riego anterior" (comparando una fecha contra sí misma, intervalo cero, la recalibración no
hacía nada). Se corrigió excluyendo el evento nuevo por `id` en la consulta, no solo confiando
en el orden de las llamadas. Quedó como comentario en el código para que no se repita si alguien
toca ese archivo después.

---

## 6. Tests: antes y después

| Momento | Resultado |
|---|---|
| Estado inicial (sin tocar nada) | 12 errores de compilación, 0 tests corriendo |
| Después de arreglar el drift de `Input` | 17/17 pasando |
| Después de instrumentar + implementar las 3 mejoras | **28/28 pasando** |

Los 11 tests nuevos: 7 de `WateringCalibrationTests` (la matemática pura de calibración), 2 de
`WateringEventRepositoryCalibrationTests` (la integración real con SwiftData, incluyendo el bug
de la sección 5), 2 de `OpenMeteoET0ProviderTests` (que el contrato de la respuesta JSON de
Open-Meteo se decodifica como se espera).

---

## 7. Prueba en el simulador real

Se compiló e instaló la app completa (`build_run_sim`) y se lanzó en `MyGarden 17 Pro`
(iOS 26.3). Resultado:

- **Arranca sin crash.** El log de la app (`os_log`) no muestra ninguna excepción ni caída.
- **Muestra datos reales correctos:** una planta existente ("Quinoto", exterior sombra) aparece
  en "Hoy" marcada "15 días de retraso", coherente con `Plant.wateringStatus` y su ciclo
  efectivo.
- **Limitación de esta sesión:** la inyección de toques (tap) del panel de control del
  simulador no llegó a la app en esta corrida (ni siquiera cambiar de pestaña respondió), un
  problema de la herramienta de control, no del código — la app en sí respondió normalmente al
  build/install/launch. No se pudo, por lo tanto, navegar a la ficha de "Quinoto" para
  confirmar visualmente el nuevo tip de drenaje en pantalla ni disparar un "Recalcular" real
  para ver el log de cross-check con Open-Meteo en vivo dentro de la app. La lógica en sí está
  cubierta por los 28 tests automatizados y por la corrida standalone de la sección 3, que usa
  el código real, no una reimplementación.

**Pendiente para una próxima sesión (no bloqueante):** repetir la navegación manual en el
simulador cuando la inyección de toques funcione, para confirmar visualmente el tip de drenaje
y una corrida real de "Recalcular" con el log de cross-check completo.

---

## 8. Resumen para decidir si "hay mejora"

- El motor base no cambió (mismos números que antes, ver sección 2): las 3 mejoras son
  aditivas, no una reescritura.
- La calibración ya tiene su propia matemática probada y aislada (sección 4), lista para
  empezar a corregir el error de reserva/sustrato en cuanto haya riegos reales registrados.
- El cross-check con Open-Meteo ya encontró algo real en su primera corrida (38% de diferencia
  en ET0, sección 3): no hace falta esperar meses para que esta mejora demuestre su valor, ya
  lo hizo en la primera comparación.
- El tip de drenaje no tiene forma de "fallar", es texto condicionado al día del mes.
- Se encontraron y arreglaron dos bugs reales que no tienen que ver con las 3 mejoras pedidas
  pero que las habrían distorsionado si no se arreglaban antes: la suite de tests rota
  (sección 0) y el bug de relación de SwiftData (sección 5).
