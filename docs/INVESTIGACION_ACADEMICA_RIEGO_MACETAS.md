# Investigación académica: cálculo preciso de riego en macetas domésticas

**Propósito:** apoyar el rediseño del motor de cálculo de riego (`WateringRuleEngine.swift`)
asumiendo que el usuario puede aportar tres datos nuevos: dimensiones reales de la maceta
(diámetro superior, diámetro inferior, altura), tipo de sustrato, y mililitros exactos
aplicados en cada riego. No se toca la parte de ET0 (FAO-56 Penman-Monteith), que ya está
bien fundamentada.

**Fecha:** septiembre de 2026.

**Método:** búsqueda en el índice de papers académicos (PubMed, bioRxiv, medRxiv, arXiv) vía
Firecrawl Research, búsqueda web filtrada a sitios de investigación, búsqueda semántica
general (Exa) para tesis y boletines de extensión universitaria de acceso abierto, y lectura
de texto completo cuando estaba disponible. Donde solo se pudo acceder al abstract, se indica
explícitamente.

---

## 1. Volumen de la maceta: fórmula de tronco de cono y fracción disponible para raíces

### 1.1 Fórmula de volumen

La maceta doméstica típica (diámetro superior ≠ diámetro inferior) es geométricamente un
**tronco de cono (frustum)**. La fórmula estándar, usada de forma consistente en toda la
literatura y en las herramientas de cálculo de sustrato para horticultura en contenedor, es:

```
V = (π × h / 3) × (R² + R×r + r²)
```

donde `R` es el radio superior, `r` el radio inferior y `h` la altura. Esta es geometría
elemental (no requiere cita de un paper específico), pero su aplicación práctica al cálculo
de sustrato en macetas está documentada, entre otras fuentes, en calculadoras de volumen de
sustrato para horticultura que la aplican explícitamente para macetas cónicas frente al error
de usar solo el diámetro superior (que sobreestima el volumen real cuando la maceta se
estrecha hacia la base).

### 1.2 ¿Existe una fracción validada del volumen geométrico para "zona de raíces"?

**Cobertura débil / gap explícito.** No se encontró ningún estudio que valide una fracción
fija y universal (por ejemplo "80% del volumen geométrico es zona radicular útil") como
concepto separado. Lo que sí está bien documentado es algo distinto y más útil para el
motor de cálculo:

- La **capacidad de contenedor (container capacity, CC)** — el porcentaje de agua que retiene
  el sustrato después del drenaje libre — **depende de la altura real del contenedor**, no es
  una propiedad fija del sustrato. Esto se debe a que el agua forma un gradiente de humedad
  vertical por gravedad: la base del sustrato queda más saturada que la parte superior. Owen y
  Altland (citado en la revisión de Kaur et al., *Agro-industrial residues as potting media*,
  PMC8500816) reportan que la capacidad de retención de agua (WHC) **disminuye un 14%** y la
  porosidad de aire **aumenta un 9%** de forma lineal cuando la altura del contenedor aumenta
  de 3.8 a 15.2 cm. Milks et al. (1989b) y Fonteno (1996) —citados repetidamente en la
  literatura de sustratos de contenedor (por ejemplo en Caballero et al., *Particle Size and
  Hydraulic Properties of Pumice*, HortScience 42(5), 2007)— formalizaron modelos que predicen
  la capacidad de contenedor real como función de la altura del contenedor, no como una
  constante del material.
- Un estudio adicional en cactus pera (*Opuntia ficus-indica*, tesis doctoral de Sawsan Hassan,
  Universidad de Palermo, disponible en `iris.unipa.it`) midió el volumen real de raíces en
  cinco volúmenes de sustrato (5, 9, 18, 33, 50 L) y encontró que la **densidad de raíces**
  (longitud de raíz por unidad de volumen de sustrato) es mayor en macetas pequeñas y menor en
  las grandes, es decir: las raíces no ocupan el volumen de forma proporcional ni uniforme, y
  la relación no es una fracción constante sino que cambia con el volumen absoluto del
  contenedor.
- El estudio de Sutherland (1984, tesis de maestría, Lakehead University, sobre semillas de
  *Picea mariana*) y la revisión sobre restricción radicular en tomate (MacKay, 1995, tesis
  doctoral, Massey University) muestran que la **relación diámetro/profundidad del contenedor**
  (forma, no solo volumen total) afecta directamente el crecimiento y la distribución de
  raíces: una maceta ancha y baja (relación 1:2) favorece mejor desarrollo que una angosta y
  profunda (1:4) del mismo volumen total.

**Conclusión honesta para esta pregunta:** la literatura no valida una "fracción de raíces"
como constante separada. La forma correcta de modelar esto, según la evidencia disponible, no
es multiplicar el volumen geométrico por una fracción arbitraria de "zona radicular", sino:
(a) calcular el volumen geométrico exacto con la fórmula del tronco de cono, y (b) aplicar la
capacidad de contenedor (% de agua retenida) del sustrato específico, idealmente ajustada por
la altura real de la maceta si se quiere ir más allá de un valor de tabla genérico. La
profundidad/forma de la maceta importa para el crecimiento de raíces y para el gradiente de
humedad, pero no hay una cifra única y validada de "fracción utilizable" que sea independiente
del sustrato y de la altura.

---

## 2. Capacidad de contenedor y agua disponible por tipo de sustrato

### 2.1 Rangos generales de referencia (norma de la industria hortícola)

**Bilderback, T.E. et al. (2005). "Healthy Substrates Need Physicals Too!" HortTechnology
15(4):747–751.** (ASHS / USDA, texto completo disponible). Tabla de rangos normales para
sustratos hortícolas de contenedor:

| Propiedad | Rango normal |
|---|---|
| Porosidad total (TP) | 50–85% |
| Espacio de aire (AS) | 10–30% |
| Capacidad de contenedor / retención de agua (CC/WHC) | 45–65% |
| Agua disponible (AW) | 23–35% |

Yeager et al. (2007), citado en **Carlile, W.R., Cattivello, C., Zaccheo, P. (2015).
"Organic Growing Media: Constituents and Properties." Vadose Zone Journal, Wiley/ACSESS
(acsess.onlinelibrary.wiley.com/doi/full/10.2136/vzj2014.09.0125)**, da rangos casi idénticos:
porosidad total 50–85%, espacio de aire 10–30%, **agua disponible 25–35%**, densidad aparente
190–700 kg/m³.

Criscione, K.S. (2021). *Evaluating Substrate Stratification Practices for Enhanced Water
Resource Management in Nursery Production*. Tesis de maestría, Louisiana State University
(LSU Digital Commons, doi.org/10.31390/gradschool_theses.5444), citando a Bilderback et al.
(2013): capacidad de contenedor recomendada **0.45–0.65 cm³/cm³**, espacio de aire
**0.10–0.30 cm³/cm³**, porosidad total **0.50–0.85 cm³/cm³**.

### 2.2 Turba (peat)

Carlile et al. (2015) presenta datos de turba por grado de humificación (escala von Post),
con agua disponible (definida como 1–10 kPa de succión) muy variable según el grado de
descomposición:

| Humificación | Densidad seca (kg/m³) | Porosidad total (%) | Espacio de aire (%) | Agua disponible (%) |
|---|---|---|---|---|
| H3 | 118 | 94.4 | 13.7 | 42.3 |
| H4 (6–12) | 118 | 92.0 | 36.3 | 21.7 |
| H4 (10–25) | 129 | 91.5 | 40.9 | 16.9 |
| H7 (3–6) | 263 | 83.8 | 42.6 | 8.1 |
| H7 (6–12) | 255 | 83.8 | 49.3 | 6.1 |

(Fuente original de los datos: Bilderback et al. 2005, tabulada dentro de Carlile et al. 2015).
Nótese que la turba menos descompuesta (H3) retiene más agua disponible (42.3%) que la muy
descompuesta (H7, 6.1–8.1%): el grado de humificación importa más que "turba" como categoría
única.

Un dato adicional, con salvedad de fuente no revisada por pares pero de una universidad
pública (UF/IFAS Extension, **Bayabil, H.K. et al. (2021). "Moisture Retention and Chemical
Properties of Nursery Potting Substrates." AE562, University of Florida IFAS**,
ask.ifas.ufl.edu/publication/AE562): turba de Florida retuvo 81% de agua por peso seco (no es
directamente comparable al % volumétrico de Carlile, pero confirma el orden de magnitud alto
de retención de la turba frente a otros materiales orgánicos evaluados en el mismo estudio).

### 2.3 Fibra de coco (coco coir)

Carlile et al. (2015), citando a **Abad et al. (2005)**:

| Origen | Densidad seca (kg/m³) | Porosidad total (%) | Espacio de aire (%) | Agua disponible (%) |
|---|---|---|---|---|
| Coir pith, Tamil Nadu (India) | 56 | 96.3 | 41.2 | 28.1 |
| Coir pith, México | 61–72 | 95.2–95.9 | 43.7–57.8 | 19.9–25.8 |

UF/IFAS AE562 (Bayabil et al. 2021) midió fibra de coco (coconut fiber) con la retención de
agua por peso seco más alta de las seis muestras estudiadas: **395% (3.95 lb de agua por lb de
sustrato seco)**, muy por encima de la turba de Florida (81%), corteza de pino (132–134%) y
madera dura (199%).

### 2.4 Corteza de pino / mezcla para orquídeas

**Bilderback, T.E. et al. (2005)**, HortTechnology 15(4), citando a Harrelson et al. (2004):
corteza de pino **fresca** tuvo agua disponible (AW) de solo **9.8%**, con espacio de aire
excesivo (39.3%) y capacidad de contenedor de 49.0%. La misma corteza **añejada un año**
alcanzó **26.3% de agua disponible**, con espacio de aire de 25.2% y capacidad de contenedor de
61.1%. Esta es una diferencia de 2.7 veces en agua disponible solo por el envejecimiento del
material, con la misma etiqueta de "corteza de pino".

**Kim, H.J., Kim, J., Yun, D.L., Kim, K.S., Kim, Y.J. (2016). "Growth and Flowering of
*Doritaenopsis* Queen Beer 'Mantefon' as Affected by Different Potting Substrates." The
Horticulture Journal 85(4). doi.org/10.2503/hortj.mi-133.** Midió directamente sustratos para
orquídeas Phalaenopsis:

| Sustrato | Capacidad de contenedor (%) | Espacio de aire (%) | Porosidad total (%) |
|---|---|---|---|
| Sphagnum 100% (S) | 61.7 | 31.8 | 93.5 |
| Turba 100% (P) | 80.7 | 6.1 | 86.8 |
| Corteza Douglas fir + turba 3:7 (BP) | 52.8 | 16.6 | 69.3 |
| Sphagnum + turba 4:6 (SP) | 82.2 | 10.0 | 92.2 |

Esto confirma que un sustrato "para orquídeas" basado en corteza sola retiene notablemente
menos agua (CC 52.8%) que uno con turba o sphagnum predominante (80–82%), pese a que ambos se
venden bajo la misma categoría comercial.

### 2.5 Perlita / mezcla para cactus y suculentas

**Cobertura débil.** No se encontró un estudio revisado por pares que mida directamente el
porcentaje de agua disponible de una "mezcla comercial para cactus/suculentas" como producto
terminado (a diferencia de turba, coco y corteza, que sí tienen mediciones directas
publicadas). Lo que sí hay:

- Extensión de la Universidad de California (Tjosvold, S.A. (2019). "Soil Mixes Part 3: How
  much air and water?" UC ANR, ucanr.edu/blog) da recomendaciones generales de diseño de
  mezcla: porosidad total ≥50%, espacio de aire ≥10%, **capacidad de retención de agua ≥40%**
  para una mezcla de contenedor genérica bien balanceada, con ejemplos medidos de
  turba+perlita (73% WHC) y turba+vermiculita (81% WHC) en maceta de 12 cm.
- Una fuente comercial no académica (Black Gold, empresa de sustratos) describe la fórmula
  típica de mezcla para cactus/suculentas como ~50% sólido (45% mineral + 5% orgánico) y 50%
  espacio de poro (25% aire + 25% agua absorbida), lo que sugiere un agua disponible
  aproximada del **25% por volumen**, sensiblemente menor que turba o coco puros. Esta cifra
  se reporta con la salvedad explícita de que **no proviene de una fuente académica revisada
  por pares**, sino de una guía de fabricante, y debería tratarse como una estimación de
  partida a validar, no como un dato con el mismo nivel de confianza que los de las secciones
  2.2–2.4.

### 2.6 Mezcla comercial genérica para macetas ("potting mix")

UF/IFAS AE562 midió una mezcla lista para usar (40% turba de Florida + 35% corteza de pino +
25% madera dura): retención de agua por peso seco de 113%, intermedia entre la turba sola
(81%) y la corteza sola (132–134%). Bilderback et al. (2005) reportan ejemplos de mezclas
comerciales de corteza:turba:pumita en proporciones 1:1:1 y 50:30:20 con agua disponible de
37% y espacio de aire de 21–23%, dentro del rango normal de la industria (23–35% AW).

---

## 3. Balance hídrico tipo FAO-56 combinado con modelo de "cubeta" para macetas

### 3.1 Sí existe, y está bien desarrollado en horticultura de vivero en contenedor

**Bacci, L., Battista, P., Rapi, B. (2008). "An integrated method for irrigation scheduling of
potted plants." Scientia Horticulturae 116(1):89–97.** Este es el estudio más directamente
relevante encontrado. Combina el método climático clásico (`ET = ET0 × Kc`, con ET0 calculado
por la ecuación CIMIS derivada de Penman) con mediciones de tensiómetro en macetas de
*Hypericum hidcote* de 2 años. Metodología: la lectura del tensiómetro se convierte en
contenido de agua vía una curva de retención específica del sustrato, y la diferencia entre
dos lecturas consecutivas de agua da la evapotranspiración real horaria (`ETt`). Esto se
compara contra la ET estimada por clima (`AET`). Resultado de precisión:

- Relación cruda tensiómetro vs. balanza de precisión: **R² = 0.7**.
- Con el Kc calculado como cociente `ETt/ET0` (en vez de un Kc de tabla): **R² = 0.896–0.907**,
  pendiente 0.77–0.907 según el promedio usado (7 días).

**Bacci, L. et al. (2011). "Modelling Evapotranspiration of Container Crops for Irrigation
Scheduling."** Capítulo del libro *Evapotranspiration — From Measurements to Agricultural and
Environmental Applications*, InTech (texto completo en cdn.intechopen.com). Describe
explícitamente una arquitectura de **umbral acumulado tipo cubeta** para macetas: "irrigation
was automatically activated whenever cumulated ET (estimated on hourly time step) of the
reference crop exceeded a predetermined value corresponding to the maximum allowed substrate
moisture deficit" — es decir, se acumula la ET hora a hora hasta superar un umbral de
agotamiento permitido del agua disponible en el sustrato, momento en el que se dispara el
riego. Esto es, literalmente, un modelo de cubeta con reposición por umbral, no una división
puntual. Resultado de precisión del modelo climático puro (regresión de altura de planta ×
ET0, cuatro especies ornamentales: *Photinia*, *Viburnum*, *Prunus*, *Forsythia*) frente a
mediciones de balanza: **R² = 0.69** agregando todas las especies, con una **desviación media
absoluta de ~23%** entre lo simulado y lo observado (rango por especie: 18% en *Prunus*, 20%
en *Forsythia*, 25% en *Viburnum*, 27% en *Photinia*). Comparado contra riego por temporizador,
el modelo de ET redujo el uso estacional de agua en **~40%** sin afectar el crecimiento ni la
ET real de los cultivos.

**Incrocci, L., Marzialetti, P., Incrocci, G., Di Vita, A., Balendonck, J., Bibbiani, C.,
Spagnol, S., Pardossi, A. (2014). "Substrate water status and evapotranspiration irrigation
scheduling in heterogeneous container nursery crops." Agricultural Water Management
131:30–40.** Comparó tres métodos durante cuatro veranos consecutivos (2007–2010) sobre cuatro
especies de arbustos ornamentales en contenedor: riego por temporizador (TIMER, práctica
habitual del vivero), riego por sensor de humedad/tensiómetro (SW), y riego por modelo de
ET (`MODEL`, ET0 × Kc estimado de la altura de planta). Resultado cuantificado: frente a
TIMER, tanto SW como MODEL **redujeron el uso de agua entre 21% y 40%** y la **emisión de
nutrientes entre 39% y 74%**, **sin efecto significativo en el crecimiento ni la calidad de la
planta**. Es decir, el modelo de balance hídrico climático (sin sensor) logró resultados del
mismo orden de magnitud que el sensor de humedad real en este experimento.

### 3.2 Arquitectura típica del modelo de cubeta para contenedores, según esta literatura

1. Estado de agua del sustrato del día anterior (medido por tensiómetro/balanza o estimado).
2. Se resta la ET del día (`ET0 × Kc`, con Kc propio de cultivo en maceta, más alto que en
   campo — ver sección 3.3).
3. Se suma el riego real aplicado ese día (y lluvia, si aplica al aire libre).
4. Se compara el estado resultante contra un umbral de agotamiento permitido (por ejemplo,
   un potencial matricial de -6 a -10 kPa, equivalente a un contenido de agua específico según
   la curva de retención del sustrato).
5. Si se supera el umbral, se dispara riego (en los estudios de vivero) o se recomienda regar
   (traducible a una app doméstica).

### 3.3 Nota sobre Kc en contenedor

Bacci et al. (2011) señalan explícitamente que el **Kc en cultivo de contenedor es típicamente
mayor que en cultivos agronómicos o árboles de huerto en campo**, que rara vez superan 1.3
(Doorenbos & Pruitt, 1975), y también mayor que los obtenidos en experimentos de lisimetría en
suelo. Esto es relevante porque el motor actual de la app usa Kc derivados de datos de hábitat
natural de la especie (Trefle), que no necesariamente capturan este efecto de "Kc de maceta".

---

## 4. Error esperado con y sin sensores

### 4.1 Comparaciones directas con cifras de agua aplicada (no exactamente "días")

**Comparación tomate, SM vs. ET (PMC11002582, revista de horticultura peer-reviewed,
"Comparative analysis in selecting best irrigation method to maximize tomato yield from
various irrigation approaches in water scarce regions"):** el agua total aplicada bajo
programación por sensor de humedad (SM) fue **229.1 mm**, frente a **280.0 mm** bajo
programación por ET, **sin diferencia significativa de rendimiento (p<0.05)** entre ambos
métodos. Es decir, el método basado solo en clima (ET) sobre-aplicó aproximadamente **22% más
agua** que el basado en sensor para lograr un resultado agronómico equivalente — un error de
sobre-riego, no de sub-riego, y no fatal para el cultivo en ese experimento.

**Incrocci et al. (2014)** (ver sección 3.1): el modelo de ET climático puro (`MODEL`) logró
ahorros de agua estadísticamente indistinguibles del método con sensor (`SW`), ambos 21–40%
mejor que el temporizador, sin diferencia de calidad de planta.

**PMC11902337 (comparación sensor IoT de bajo costo vs. clima en lechuga):** un hallazgo
relevante para la fiabilidad de sensores baratos (no para el modelo climático): la
calibración específica del sitio **mejoró la estimación del contenido de agua del suelo en un
45% en limo arcilloso y 42% en arena limosa**, reduciendo la propagación de error hacia la
decisión de riego. Esto es evidencia de que un sensor barato sin calibración específica del
sustrato también tiene un error sustancial, no es una "verdad de referencia" automática.

### 4.2 Error cuantificado en días (agricultura de campo, no maceta — aplicar con cautela)

**Kallestad, J.C., Mexal, J.G., Sammis, T.W., Heerema, R.J. (2008). "Development of a Simple
Irrigation Scheduling Calendar for Mesilla Valley Pecan Growers." HortTechnology 18(4):714.**
Este estudio construyó una herramienta de programación de riego basada solo en 14 años de
datos climáticos archivados y una regla de lluvia acumulada, sin sensores de campo, validada
por simulación contra un modelo de referencia. Resultado: las fechas de riego programadas con
la herramienta climática estuvieron **dentro de 3 días de las fechas predichas por el modelo
de referencia en suelo franco-arcilloso-limoso y franco**, y **menos de 2 días de diferencia en
suelo franco-arenoso y arena**. Esta es la cifra más directa encontrada en la literatura para
"error en días de una programación puramente climática, sin sensor", aunque el contexto es
riego de nogal pecanero en campo abierto, no macetas domésticas — el error real en un
contenedor pequeño doméstico, con mucho menor volumen de reserva que un suelo de huerto, sería
esperablemente mayor en términos relativos (aunque no hay un estudio de maceta doméstica
equivalente que dé una cifra directa comparable en días).

### 4.3 Cobertura débil para el caso específico de maceta doméstica

**Gap explícito:** no se encontró un estudio que cuantifique en días de error (en vez de en mm
o % de agua aplicada) la diferencia entre programar el riego de una planta en maceta *solo*
con clima y características físicas conocidas, frente a hacerlo con sensor de humedad,
específicamente para el caso de contenedores pequeños de interior/balcón doméstico. Los
estudios disponibles son de vivero comercial (contenedores de producción, no macetas de
interior) o de campo abierto (pecanos). La extrapolación razonable, dado que los ciclos de
secado en macetas pequeñas domésticas son de apenas 4 a 8 días (como ya se documentó en el
análisis previo del proyecto), es que un error de "unos pocos días" —que en un huerto de
pecanos es una fracción pequeña del ciclo de riego— representa una fracción mucho mayor
(potencialmente 50–75%) del ciclo completo en una maceta doméstica pequeña. Esto es
consistente con, pero no está directamente demostrado por, ningún estudio de la literatura
revisada.

---

## 5. Fracción de lixiviación y modelo de agua retenida

### 5.1 Definición y valores objetivo estándar de la industria

La fracción de lixiviación (leaching fraction, LF) se define de forma consistente en toda la
literatura de vivero en contenedor como:

```
LF = volumen de agua que drena por el fondo / volumen de agua aplicado
```

**Fuentes con protocolo de medición y valores objetivo, todas de extensión universitaria:**

- **Virginia Tech Cooperative Extension, SPES-128, "Leaching Fraction: A Tool to Schedule
  Irrigation for Container-Grown Nursery Crops"** (ext.vt.edu): LF objetivo típico **15% a
  30%**, según sistema de riego.
- **UF/IFAS Extension, EP529, "Monitoring Leaching Fraction for Irrigation Scheduling in
  Container Nurseries"** (Jeff Million, ask.ifas.ufl.edu): protocolo de medición por peso y
  por volumen, con fórmula de ajuste de tiempo de riego:
  `tiempo_nuevo = tiempo_actual × (100% - LF_medida) / (100% - LF_objetivo)`.
- **Fessler, L., Fulcher, A. (2023). University of Tennessee Extension, D200.** LF objetivo
  **10–15% para riego por aspersión (overhead), 25–30% para micro-riego (spray-stake)**.
- **Million, J.B., Yeager, T.H. (2021). "Use of Routine Leaching Fraction Testing to Guide
  Irrigation at a Container Nursery." Journal of Environmental Horticulture 39(3):108.**
  Confirma los mismos objetivos (10–15% aspersión, 25–30% micro-riego) y los usa en un sistema
  automatizado real (CIRRIG) que ajusta el tiempo de riego diario en un vivero comercial
  combinando ET y LF medida.

### 5.2 El modelo simple validado para agua retenida

El modelo aritmético usado de forma consistente en toda esta literatura (no es una
"propuesta" nueva, es la definición operativa estándar de la industria) es:

```
agua_retenida = agua_aplicada × (1 − LF)
```

Es decir, si se aplican 500 ml y la fracción de lixiviación es 20%, quedan retenidos
**400 ml** en el sustrato. Esta es exactamente la relación que el motor de cálculo necesitaría
para convertir "ml aplicados por el usuario" en "mm de reserva efectiva añadida al balance",
en vez de asumir que el 100% del agua aplicada queda disponible.

### 5.3 ¿La fracción de lixiviación depende de forma predecible de las propiedades del sustrato?

Sí, con matices. Un estudio con relevancia directa:

**"Effluent Volumes to Control Leaching in Large Container Nursery Crops"** (resumen de póster,
ASHS 2012, republicado por IPPS, actahort.org/books/1014/1014_39.htm): se secó sustrato de
corteza de pino gruesa a 95%, 80% y 70% de la capacidad de contenedor en tres tamaños de
maceta (3.8, 10.4, 20.7 L), y luego se regó para alcanzar fracciones de lixiviación objetivo de
0.0, 0.2, 0.4 y 0.6. Hallazgo: las fracciones de lixiviación reales fueron **sistemáticamente
mayores que el objetivo** y variaron según la humedad antecedente del sustrato, pero se
encontró una **relación lineal** entre el porcentaje de la capacidad de contenedor aplicado al
terminar el riego y el porcentaje total lixiviado, **independiente de la humedad antecedente**.
Esto sugiere que, conociendo la capacidad de contenedor del sustrato (sección 2) y el volumen
aplicado en relación con ella, sí es posible estimar de forma razonablemente simple —aunque no
perfecta— cuánta agua queda retenida, sin necesitar medir el drenaje real cada vez.

**Nota de honestidad metodológica:** esta fuente es un resumen de póster de conferencia
(no un artículo completo con datos tabulados accesibles en este momento), así que la relación
lineal se reporta como hallazgo cualitativo confirmado por el resumen, sin poder citar aquí
los coeficientes exactos de esa regresión.

---

## Implicaciones para el motor de cálculo (`WateringRuleEngine.swift`)

### 1. Reemplazar `reserva_mm = diámetro_cm × 2.2` por volumen real + capacidad de contenedor

Con las tres dimensiones nuevas (diámetro superior, diámetro inferior, altura):

```
volumen_sustrato_L = (π × altura_cm / 3) × (R_cm² + R_cm×r_cm + r_cm²) / 1000
agua_disponible_L  = volumen_sustrato_L × AWC_sustrato   // AWC en fracción, no %
```

`AWC_sustrato` sale de una tabla por tipo de sustrato (sección 2), no de una sola constante.
No hay evidencia que valide multiplicar además por una "fracción de zona radicular" separada
(sección 1.2): la capacidad de contenedor ya es la cifra correcta a usar directamente sobre el
volumen geométrico completo. Si se quiere mayor rigor, se puede aplicar la corrección conocida
de que la capacidad de contenedor cae con la altura del recipiente (Owen & Altland: -14% WHC
al pasar de 3.8 a 15.2 cm de altura), pero esto es una mejora de segundo orden, no
imprescindible para la primera versión.

### 2. Tabla de AWC% por sustrato, con fuentes

| Sustrato | AWC recomendado (rango) | Fuente | Confianza |
|---|---|---|---|
| Turba (peat), general | 25–35% | Yeager et al. 2007 / Carlile et al. 2015 | Alta (revisión académica) |
| Turba poco descompuesta | ~40–42% | Carlile et al. 2015 (datos H3) | Alta |
| Turba muy descompuesta | ~6–8% | Carlile et al. 2015 (datos H7) | Alta |
| Fibra de coco (coco coir) | 20–28% | Abad et al. 2005, vía Carlile et al. 2015 | Alta |
| Corteza de pino / orquídea, fresca | ~10% | Harrelson et al. 2004, vía Bilderback et al. 2005 | Alta |
| Corteza de pino / orquídea, añejada | ~26% | Harrelson et al. 2004, vía Bilderback et al. 2005 | Alta |
| Mezcla turba+corteza para orquídeas (3:7) | CC ~53% (no AWC puro) | Kim et al. 2016 | Alta |
| Mezcla comercial genérica | 23–37% | Bilderback et al. 2005 / UF IFAS AE562 | Alta |
| Cactus / suculentas | ~25% (estimado) | Fuente comercial, no revisada por pares | **Baja — validar con medición propia o extensión universitaria antes de fijar el valor en producción** |

Recomendación concreta: usar rangos medios de tabla como valor por defecto por tipo de
sustrato, y dejar explícito en la UI/documentación que el valor de cactus/suculentas es una
estimación provisional pendiente de mejor fuente.

### 3. Migrar a un modelo de cubeta con ml aplicados reales: sí vale la pena, y no es una idea nueva

La sección 3 confirma que instituciones de investigación en horticultura de contenedor
(Pisa/CESPEVI en Italia) ya usan exactamente esta arquitectura en producción, con reducciones
de agua del 21–40% frente a un enfoque sin retroalimentación, sin pérdida de calidad de
planta. Cambio concreto propuesto:

```
estado_hoy_mm = estado_ayer_mm + (ml_aplicados_hoy / area_superficie_cm² × 0.1) × (1 − LF) − ETc_hoy_mm
```

donde `ETc_hoy_mm = ET0 × Kc × modificadores` (sin cambios respecto al motor actual), y el
riego se recomienda cuando `estado_hoy_mm` cae por debajo de un umbral de agotamiento (por
ejemplo, 40–60% del agua disponible total, en línea con los umbrales de -6 a -10 kPa usados en
Bacci et al. 2008/2011). Esto reemplaza la división puntual actual
(`reserva_efectiva / perdida_diaria = ciclo_dias`) por un balance acumulado día a día, que ya
existía como propuesta priorizada en el análisis previo del proyecto y que esta investigación
confirma con literatura real, no solo con la revisión cruzada de IAs.

### 4. Convertir ml aplicados en mm de reserva: aplicar la fracción de lixiviación

```
agua_retenida_mm = (ml_aplicados / area_superficie_cm²) × 0.1 × (1 − LF_estimada)
```

Con `LF_estimada` entre 0.10–0.15 si el usuario riega "hasta que empiece a gotear un poco"
(riego por gravedad, equivalente a aspersión) o 0.25–0.30 si riega en exceso deliberadamente
(equivalente a micro-riego con más margen). Esto le da uso real y validado por literatura al
dato de "ml aplicados" que hoy la app no pide, evitando el error de asumir que el 100% del
agua aplicada queda disponible para la planta.

### 5. Techo de precisión esperado, con y sin sensor

- **Sin sensor, con el modelo mejorado (volumen real + sustrato + ml aplicados + cubeta):** la
  literatura de vivero en contenedor (Incrocci et al. 2014, Bacci et al. 2011) muestra que un
  modelo climático bien calibrado puede acercarse al desempeño de un sensor de humedad real
  (ahorros de agua estadísticamente indistinguibles, 21–40% en ambos casos frente a un método
  sin retroalimentación). Esto es evidencia real de que el techo de precisión sin sensor **no
  es tan bajo como el análisis previo asumía**, siempre que el modelo tenga buena calibración
  de Kc de contenedor y buena estimación de la reserva real (exactamente lo que este documento
  propone mejorar).
- **Con sensor barato sin calibración específica de sustrato:** el error de calibración puede
  ser sustancial (mejoras de 42–45% en precisión solo por calibrar el sensor al sustrato/suelo
  específico, según PMC11902337), consistente con lo ya señalado en el análisis previo sobre
  deriva de calibración por sales. Un sensor no es automáticamente más preciso que un buen
  modelo si no está bien calibrado.
- **Error en días, específico de maceta doméstica pequeña:** sigue siendo un **gap de la
  literatura** (sección 4.3). La única cifra concreta en días encontrada (Kallestad et al.
  2008, 2–3 días de error) es de riego agrícola de campo, no de maceta doméstica, y
  probablemente subestima el error relativo en un contenedor pequeño con ciclos de secado de
  4–8 días. No se debe presentar esa cifra de 2–3 días como aplicable directamente a macetas
  sin esa salvedad.

### 6. Qué no se pudo confirmar (resumen de gaps)

- No hay validación académica de una "fracción de zona radicular" separada de la capacidad de
  contenedor (sección 1.2).
- No hay medición académica publicada de AWC% para mezclas comerciales de cactus/suculentas
  como producto terminado (sección 2.5); el valor usado hoy sería una estimación, no un dato
  duro.
- No hay una cifra de error en días, específica de maceta doméstica pequeña, comparando
  climático-sin-sensor contra sensor-de-humedad (sección 4.3); solo hay cifras de vivero
  comercial y de riego agrícola de campo, extrapolables con cautela.
