# newGardenNew

App iOS de cuidado de plantas. Es la reimplementación de **MyGarden**, una app funcional
pero con problemas graves de UX que se analizaron en detalle antes de empezar esto.

## Antes de tocar nada

Lee, en este orden:

1. **`docs/HANDOFF.md`** - El traspaso. Explica de dónde viene el proyecto, qué está
   decidido, cómo consultar dudas y por dónde empezar.
2. **`docs/REPORTE_ESTADO_Y_REDISENO.md`** - El análisis completo (818 líneas): auditoría
   técnica, auditoría UX contra las 10 heurísticas de Nielsen, comparación con las guías
   de Apple para iOS 26 y 27, y las 14 propuestas de cambio con su justificación.
3. **`docs/diagrams/*.png`** - Arquitectura actual, arquitectura propuesta, pipeline de IA
   antes y después, y arquitectura de información.

## Estado

Proyecto recién creado desde plantilla de Xcode (SwiftData). Ya tiene copiado y compilando:

```
newGardenNew/DesignSystem/   Tokens y componentes aprobados por el usuario
newGardenNew/Mockups/        Las 11 pantallas propuestas, ejecutables, en #if DEBUG
newGardenNew/Assets.xcassets/DS/   11 colorsets con variante clara y oscura
```

Todo lo demás está por hacer.

## Configuración

| Ajuste | Valor |
|--------|-------|
| Bundle ID | `com.ipo.newGardenNew` |
| Team | El tuyo (`DEVELOPMENT_TEAM` vacío en el repo) |
| Deployment target | iOS 26.2 |
| Swift version | 5.0 **(hay que subirlo a 6.0)** |
| Xcode | 26.3 |
| Simulador disponible | `MyGarden 17 Pro` (iOS 26.3) |

## Convenciones

- Código en inglés, textos de interfaz en español (y en inglés vía `Localizable.xcstrings`)
- MVVM: View, ViewModel `@Observable`, Repository, SwiftData
- Inyección de dependencias por protocolo. Los ViewModels **reciben** los servicios, no los instancian
- Todo espaciado, radio, color y estilo de texto sale de `DesignSystem/DSTokens.swift`.
  Nada de números mágicos ni hexadecimales sueltos: ese fue uno de los hallazgos del análisis
- Liquid Glass solo en la capa de navegación, nunca en el contenido
- Cada estado de riego se comunica con **color, forma y texto a la vez**, nunca solo color
- Sin guiones largos en ningún texto (preferencia del usuario)

## Seguridad de git (importante)

- **Nunca** hagas commit, push, reset, checkout, rebase, merge ni stash
- Solo comandos de lectura: `git status`, `git diff`, `git log`
- Si hay que commitear, escribe los comandos como texto para que los ejecute el usuario

## Trabajo por checkpoints

Al terminar cada fase, usa `AskUserQuestion` con tres opciones: Continuar, Revisar, Corregir.
Nunca presentes el checkpoint como texto plano. En español.
