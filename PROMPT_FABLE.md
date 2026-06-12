# Prompt para Fable — Kuidar: sincronización con `main` + nueva lógica de negocio

## 0. Contexto del proyecto (PRODUCT.md — léelo y respétalo en TODO)

```
# Product

## Users
Tres roles en México (es_MX):
- **Familiares**: adultos ocupados que coordinan ayuda para sus padres/abuelos. Usan la app en momentos breves del día, con carga emocional.
- **Becarios**: estudiantes universitarios que cumplen horas de servicio social haciendo visitas. Móvil-first, en tránsito.
- **Adultos mayores**: usuarios de baja fluidez digital. Necesitan tipografía grande, flujos de un solo paso y lenguaje directo.

## Product Purpose
Kuidar conecta familias con becarios universitarios para acompañar y asistir a adultos mayores (mandados, citas médicas, compañía, ayuda digital). Éxito = una visita publicada, aceptada, realizada y verificada por GPS sin fricción, con confianza entre las tres partes.

## Brand Personality
Cálido, confiable, humano. La calidez viene del tono de voz y del color de acento — nunca de decoración. Tres palabras: cuidado, claridad, cercanía.

## Anti-references
- Apps de gig-economy frías (Uber-like): transaccional, impersonal.
- Salud institucional (azul hospital, formularios infinitos).
- AI slop: emojis como iconos, gradientes decorativos en texto, cards idénticas en grid, eyebrows uppercase en cada sección.

## Design Principles
1. El adulto mayor manda el piso de accesibilidad: si la pantalla la ve un adulto mayor, tipografía ≥ body grande, contraste ≥4.5:1, un CTA por pantalla.
2. Nativo primero: SF Symbols, componentes de sistema (List, Form, ContentUnavailableView), haptics estándar. La app debe sentirse de Apple, no de plantilla web.
3. El teal es la firma: #167B70 ancla la identidad. Roles se distinguen por tinte (teal familia, verde becario, naranja adulto mayor) pero el teal es la voz de la marca.
4. Motion comunica estado: 150–250ms, ease-out. La única excepción coreografiada es la apertura de la app (splash→login, ~1.2s). Reduce Motion siempre respetado.
5. Confianza visible: estados en vivo (GPS, websocket), verificación, y progreso siempre a la vista — la confianza entre extraños es el producto.

## Accessibility & Inclusion
- Prioridad alta: Dynamic Type en todas las pantallas, contraste ≥4.5:1, targets ≥44pt.
- `accessibilityReduceMotion` respetado en toda animación.
- VoiceOver: iconos decorativos ocultos, elementos combinados con labels en español.
```

**Nota sobre "Anti-references" vs. el punto 15 de este prompt (flujo tipo Uber):** el punto 15 pide explícitamente un flujo de confirmación doble + review al estilo Uber. Esto tiene prioridad sobre el anti-reference de "Uber-like" del PRODUCT.md — implementa la *funcionalidad* (doble confirmación, tracking, review post-servicio), pero mantén el tono cálido/humano de Kuidar en los textos, iconografía y colores (nada de lenguaje transaccional ni UI fría).

**Stack:** iOS app en SwiftUI (target `tecSwiftChallenge2026`), backend Node.js/TypeScript + Express + SQLite (`better-sqlite3`) + WebSocket nativo (`ws`), sin frameworks pesados. **Restricción dura: NO usar APIs externas de terceros para nada** (ni para chat, ni para notificaciones push, ni para IA, ni para mapas/geocoding más allá de MapKit/CoreLocation que ya son nativos de Apple). Toda la lógica de chat, notificaciones e IA de recomendación debe ser local/propia (server SQLite + WebSocket + heurísticas en Swift/TS).

---

## 1. Sincronización con `main` (PRIORIDAD DE MERGE)

El repo remoto (`https://github.com/ManuelPerezF/tecSwiftChallenge2026`) tiene commits más recientes que el `HEAD` local (`de08d61`). En orden descendente, los nuevos commits que vimos en GitHub son:

1. `750ef35` — "quitar badges"
2. `8726862` — "feat: add real-time bidirectional chat and reputation display"
3. `68fa60b` — "style: UI changes to make it feel premium"
4. `8bf3bee` — "feat: demo requests seed and student UI polish"
5. `81afdb9` — "feat: splash logo, adulto mayor UX, map pins"
6. `de08d61` — "refactor: drop hardcoded config and demo UI data" ← este es el HEAD local actual

**IMPORTANTE:** no pude descargar/leer el diff de los commits 1–5 (sin acceso de red al repo desde este entorno), así que **tú (Fable) debes hacer `git fetch origin` / `git pull origin main` primero**, revisar esos 5 commits, y traerlos a la rama de trabajo **sin perder los cambios locales sin commitear** que ya existen en el working tree (incluyen carpetas nuevas `tecSwiftChallenge2026/Views/Organizer/` y `tecSwiftChallenge2026/Components/AI/`, y modificaciones en varios archivos de `server/src`, `server/dist` y vistas Swift — usa `git stash` antes del pull/merge y luego `git stash pop`, resolviendo conflictos a mano).

**Regla de prioridad ante conflictos (MUY IMPORTANTE):**
- El commit `8726862` ("feat: add real-time bidirectional chat and reputation display") probablemente ya implementa una versión del sistema de chat y de visualización de reputación. **Revísalo y reutiliza/extiende lo que sirva**, pero el punto 14 de este documento (reglas de negocio del chat: quién puede hablar con quién, permisos de control parental del punto 16, etc.) **manda sobre lo que traiga ese commit** si hay choque de lógica o reglas de negocio.
- Lo mismo aplica a `68fa60b` (UI premium), `8bf3bee` (seed de requests / polish de student) y `81afdb9` (splash, UX adulto mayor, pines de mapa): **si esos cambios de diseño/UI no entran en conflicto de usabilidad con los puntos 1–16 de abajo, conérvalos tal cual** (no los deshagas, no los repliques con un estilo distinto). **Si entran en conflicto** (por ejemplo, una vista que ese commit reorganizó pero que el punto 11 pide reorganizar de otra forma, o un componente de mapa que el punto 10 pide reubicar), **gana lo especificado en este documento**.
- En general: **tus cambios locales sin commitear (Organizer/, AI/, etc.) + los puntos 1–16 de abajo > commits nuevos de main > estado previo de main**. El objetivo final es un único árbol coherente que contenga absolutamente todo: lo de main, lo tuyo local, y la nueva lógica de negocio pedida — sin duplicar pantallas ni regresar funcionalidad.

Antes de tocar nada, genera un resumen corto (para Santi) de:
- Qué trae cada uno de los 5 commits nuevos.
- Qué conflictos detectaste contra los puntos 1–16.
- Cómo los resolviste.

---

## 2. Estado actual del código (para que ubiques rápido qué tocar)

- **Modelos Swift**: `tecSwiftChallenge2026/Models/Models.swift` — `ActivityType`, `TimeWindow`, `RequestStatus`, `AssignmentStatus`, `APIRequest`, `APIAssignment`, `APIApplication`, `FamilyInfo`, `ElderlySummary`, `StudentProfile`, `APIRating`, `APIBadge`, `APILocation`.
- **Login/registro**: `tecSwiftChallenge2026/App/LoginView.swift` — un solo `SecureField` para password (login y registro comparten el mismo campo), sin toggle de visibilidad.
- **Organizador**: `tecSwiftChallenge2026/Views/Organizer/OrganizerRootView.swift` (+ `CommunityEventsView.swift`) — TabView con tabs "Eventos" y "Crear evento" (cada uno con su propio botón "Cerrar sesión" en la toolbar). `OrganizerCreateEventView` usa el grid de `ActivityType.allCases` como "Tipo de actividad" y un `Stepper(value: $maxHelpers, in: 2...20)`.
- **Familia**: `Views/Family/FamilyRootView.swift` (4 tabs: Publicar, Solicitudes, Eventos, Mi familia, cada uno con logout en toolbar), `FamilyPublishView.swift`, `FamilyDashboardView.swift` (botón "+" en toolbar para nueva solicitud), `FamilyManageView.swift` (código de familia + lista de adultos mayores **solo lectura**), `FamilyApplicantsView.swift` (incluye `FamilyLiveVisitView`), `FamilyStudentProfileView.swift`.
- **Becario**: `Views/Student/StudentRootView.swift` (3 tabs: `[Mapa, Visitas, Horas]`, Mapa primero), `StudentMapView.swift`, `StudentCommitmentsView.swift` (flujo de avance: En camino → Iniciar → Confirmar → Terminé), `StudentHoursView.swift`, `StudentDetailView.swift`.
- **Adulto mayor**: `Views/Elderly/ElderlyRootView.swift`, `ElderlyAgendaView.swift`, `ElderlyFamilyView.swift`, `ElderlyVisitView.swift`, `ElderlyRatingView.swift`.
- **Componentes**: `Components/APIClient.swift`, `APIConfig.swift`, `WebSocketClient.swift`, `DesignSystem.swift`, `LocationGrabber.swift`, `SharedComponents.swift`, y los nuevos (sin commitear) `Components/AI/HelperRecommender.swift`, `Components/AI/IntentParser.swift`.
- **Backend** (`server/src/modules/`): `assignments`, `applications`, `auth`, `badges`, `families`, `requests`, `students`, `ratings`, `universities`. WS en `server/src/ws/socketServer.ts`.
  - `assignments.service.ts` ya tiene el flujo: `enCamino` → `iniciar` (solicita inicio, sin contar horas) → `confirmarInicio` (adulto mayor confirma, arranca cronómetro real con `checkin_at`) → `completar` (becario, calcula `hours_logged` real desde `checkin_at`/`checkout_at`, mínimo 0.25h, suma a `students.total_hours`, dispara `badgesService.evaluate`). `cancelar` solo lo puede hacer la familia.
  - `requests.service.ts`: `isCommunityEvent`, `maxHelpersRequired` (mínimo forzado a 1 en backend, ya correcto), `activeHelpers`. No existe campo para cupo de adultos mayores ni estado "lleno".
  - No existe módulo de notificaciones, ni de chat (salvo lo que traiga el commit `8726862`, ver sección 1), ni de bloqueo de becarios, ni de control parental.

---

## 3. Especificación funcional — implementar TODO lo siguiente

### 3.1 Mostrar/ocultar contraseña al crear cuenta
En `LoginView.swift`, en el modo de registro (`isRegistering == true`), agrega un botón tipo "ojo" (`eye` / `eye.slash`, estándar de iOS) dentro del campo de contraseña que alterna entre `SecureField` y `TextField` (manteniendo el mismo binding `$password`, mismo estilo visual, mismo `focusedField`). Aplica también en login si tiene sentido visualmente (consistencia), pero el requerimiento explícito es para el flujo de creación de cuenta.

### 3.2 Organizador — "Tipo de evento" desde catálogo en BD (no `ActivityType` fijo)
- En `OrganizerCreateEventView`, el selector "Tipo de actividad" deja de usar `ActivityType.allCases`. En su lugar:
  - Crea un nuevo módulo backend `event-types` (tabla `event_types`: `id`, `slug`, `label`, `icon` (SF Symbol name), `is_custom` (bool), `created_by_organizer_id` nullable, `created_at`).
  - Precarga (seed) varios ejemplos estándar (ej. los que ya existen en `ActivityType`: mandados, citas médicas, ayuda digital, tareas del hogar, compañía, medicamentos, y agrega algunos orientados a eventos comunitarios: "Recreación", "Taller", "Ejercicio/movilidad", "Conferencia/charla").
  - Agrega siempre la opción **"Otro"** al final del picker. Al seleccionarla, muestra un campo de texto para que el organizador escriba el nombre del nuevo tipo de evento + un picker de icono (subset curado de SF Symbols). Al publicar, si es "Otro", primero crea el `event_type` custom (`is_custom = true`, asociado al organizador) vía API y luego usa su `id`/`slug` como `activityType` del evento.
  - Endpoints: `GET /event-types` (lista catálogo + custom visibles), `POST /event-types` (crear custom, solo rol organizer).
  - `APIRequest.activityType` pasa de ser un `ActivityType` enum cerrado a aceptar cualquier `slug` de `event_types` para eventos comunitarios (mantén `ActivityType` para solicitudes normales de familia, que no cambian). Ajusta `activityTypeEnum` para hacer fallback genérico (icono/label desde el catálogo) cuando el slug no esté en `ActivityType`.

### 3.3 Mínimo de becarios = 1
En `OrganizerCreateEventView`, cambia `Stepper(value: $maxHelpers, in: 2...20)` a `in: 1...20`. El backend ya soporta mínimo 1 (`Math.max(data.maxHelpersRequired ?? 1, 1)` en `requests.service.ts`), no requiere cambio adicional salvo verificación.

### 3.4 "Crear evento" como acción superior, no como tab
- En `OrganizerRootView`, elimina el tab inferior "Crear evento". El `TabView` del organizador queda con un solo tab principal "Eventos" (o se reestructura según 3.5 para incluir "Becarios" también).
- En la vista de Eventos (`CommunityEventsView` para organizador), agrega en la barra superior (toolbar / navigation bar) un botón con icono "+"/`square.and.pencil` que navegue (push o sheet) a `OrganizerCreateEventView`. Al publicar, regresa a la lista de eventos (igual que `onPublished` ya hace hoy).

### 3.5 Nueva sección "Becarios" para el organizador
- Agrega un nuevo tab/sección "Becarios" en `OrganizerRootView` (junto a "Eventos").
- Lista todos los becarios (`GET` nuevo o extensión de `students` module: `GET /students` con filtros), con:
  - Filtro/orden por mejor calificado (`averageRating` desc) y otros filtros razonables (universidad, carrera, tags/intereses).
  - Tap → perfil de detalle completo (reutiliza/extiende `FamilyStudentProfileView` o crea un equivalente para organizador): horas totales, rating, badges, ratings/comentarios recibidos, tags.
- **Vista de perfiles bloqueados** (solo organizador): sección/filtro adicional que muestre becarios cuyo perfil está **bloqueado** (ver 3.x nuevo: sistema de bloqueo, abajo), mostrando:
  - Motivo del bloqueo.
  - El/los comentario(s) de la familia que originaron el bloqueo (de `ratings`/reportes).
  - Fecha del bloqueo.
- **Nuevo: sistema de bloqueo de becarios** (backend):
  - Tabla `student_blocks` (`id`, `student_id`, `reason`, `source_rating_id` nullable, `source_family_id` nullable, `comment`, `created_at`, `active`).
  - Regla de negocio: cuando una familia deja un rating/reporte negativo (define un umbral razonable, ej. ≤2 estrellas con bandera "reportar" o un nuevo campo `isReport` en `ratings`), se crea un registro en `student_blocks` y el becario queda bloqueado (`students.is_blocked = true` o vía join con `student_blocks.active`).
  - Un becario bloqueado **no puede aceptar/postularse a nuevas solicitudes ni eventos** (valida en `applications.service.ts`).
  - Endpoints: `GET /organizer/students` (lista + filtro `blocked=true`), `GET /organizer/students/:id` (detalle con historial de bloqueos y comentarios).
  - Esta misma vista de "ver todos los detalles del perfil" debe ser reusable: aplica también a los perfiles que la familia ve de becarios (`FamilyStudentProfileView`) y a cualquier otro lugar donde se muestre un perfil — mismo componente, distintos permisos de visibilidad (el detalle de bloqueo solo lo ve el organizador).

### 3.6 Sistema de notificaciones (in-app, sin APIs externas)
Construye un módulo de notificaciones backend (`server/src/modules/notifications/`):
- Tabla `notifications` (`id`, `user_id`, `type`, `title`, `body`, `data` (JSON), `read`, `created_at`).
- Entrega vía WebSocket (push al socket del usuario conectado) + endpoint `GET /notifications` (historial) + `POST /notifications/:id/read`.
- **Disparadores y reglas:**
  1. **Nueva solicitud/servicio creado por familia** → para becarios cercanos:
     - Calcula distancia (usa la misma fórmula haversine simplificada que ya usa `toOpenRequest` en `Models.swift`) entre la ubicación del becario (última `location_updates` o ubicación de perfil si la tienen) y la solicitud.
     - Solo notifica si: (a) el becario está dentro de un radio razonable (ej. 5 km, configurable) **y** (b) la `scheduledDate` cae dentro de la disponibilidad/jornada declarada del becario (si no existe ese campo aún, agrégalo: `students.available_windows` o reutiliza `TimeWindow`).
     - La notificación debe pedir **confirmación explícita**: "¿Estás disponible y cerca para esta actividad?" con acciones Sí/No — al tocar "Sí" se comporta como abrir el detalle/postularse; "No" descarta.
  2. **Nuevo evento comunitario creado por organizador** → misma lógica de notificación a becarios cercanos + dentro de horario, **y además** a familias cercanas (para que los adultos mayores puedan asistir): notifica a las familias cuyo(s) adulto(s) mayor(es) estén dentro de un radio razonable del evento.
  3. Todas las notificaciones se ven en: vista de Familia, vista de Becario, vista de Adulto mayor (cuando aplique — ver 3.10 para el caso especial de matches de IA).

### 3.7 Becario puede modificar/cancelar su solicitud/asignación
- Nuevo endpoint en `assignments` (o `applications`): `PATCH /assignments/:id` para que el becario, mientras el estado sea `approved` (aún no inició camino), pueda:
  - Cancelar su asignación (libera el cupo, reabre la solicitud — reutiliza la lógica de reapertura que ya existe en `cancelar`, pero ahora iniciada por el estudiante en vez de la familia).
  - Proponer cambio de hora (`scheduledDate`): esto requiere aprobación de la familia (crea un registro de "propuesta de cambio" pendiente, notifica a la familia, y la familia acepta/rechaza vía endpoint nuevo).
- En `StudentCommitmentsView`, agrega UI (botón/menu contextual) en `AssignmentCard` para "Cancelar" y "Proponer otro horario", visibles solo cuando `statusEnum == .approved`.
- Notifica a la familia (vía sistema de 3.6) cuando el becario cancela o propone cambio.

### 3.8 Regla de los 15 minutos para "Voy en camino"/"Llegué"
- Backend (`assignments.service.ts`, función `enCamino` e `iniciar`): valida que la hora actual esté dentro de la ventana `[scheduledDate - 15min, scheduledDate]`. Si el becario intenta marcar "Voy en camino" o "Llegué" antes de `scheduledDate - 15min`, rechaza con `AppError` (409, código `TOO_EARLY`) y mensaje claro ("Podrás iniciar 15 minutos antes de la cita"). Si lo intenta **después** de `scheduledDate` (llegada tardía), **no lo bloquees** — solo permite desde 15 min antes hasta cualquier momento posterior (la restricción es solo "no antes de 15 min", nunca "después"). Re-lee el enunciado: "que solo deje llegar 15 minutos antes, nunca después de la cita" — interpretamos esto como: el **límite temprano** es 15 min antes (no puede marcar "voy en camino"/"llegué" antes de ese punto); no implementamos bloqueo por llegar tarde, pero si quieres lo más estricto, también puedes añadir un aviso (no bloqueo duro) si se marca "llegué" después de `scheduledDate + N min` para que el becario sepa que va tarde. Implementa al menos el bloqueo "no antes de 15 min".
- Frontend (`StudentCommitmentsView`): deshabilita visualmente el botón de avance con un contador ("Disponible en X min") cuando aplique, y muestra el error del backend si se intenta antes de tiempo.

### 3.9 Eventos: límite de adultos mayores + estado "lleno"
- Backend: agrega a `activity_requests` (o tabla específica de eventos) los campos `max_elderly_attendees` (int, definido por el organizador al crear el evento — agrega este campo al formulario de `OrganizerCreateEventView`) y `active_elderly_attendees` (contador).
- Nuevo endpoint para que un adulto mayor (o su familia en su nombre) se inscriba/desinscriba a un evento: `POST /requests/:id/attend` / `DELETE /requests/:id/attend`. Incrementa/decrementa `active_elderly_attendees`.
- Estado derivado **"lleno"**: agrega `full` a `RequestStatus` (Swift) y al enum de estados del backend. Un evento pasa a `full` cuando `active_elderly_attendees >= max_elderly_attendees` **o** `active_helpers >= max_helpers_required` (cualquiera de los dos topes). Mientras esté `full`, no se permiten nuevas inscripciones de adultos mayores ni nuevas postulaciones de becarios (valida en backend en ambos endpoints). Si se libera un cupo (cancelación), vuelve a `open` (reutiliza patrón de reapertura existente).
- UI: en `CommunityEventsView`, muestra el cupo de adultos mayores igual que ya se muestra `helpersLabel` para becarios (ej. "3/10 adultos mayores"), y el badge de estado "Lleno" cuando corresponda (estilo similar a `StatusRow`/`BadgeLabel` existentes).

### 3.10 Mapa al centro en el perfil de becario
En `StudentRootView`, reordena el `TabView` de `[Mapa, Visitas, Horas]` a `[Visitas, Mapa, Horas]` (Mapa queda en medio de las 3 secciones inferiores). No cambies el contenido de cada vista, solo el orden de los tabs (y el `selectedTab` inicial puede seguir siendo `.map` si quieres que abra ahí, o cambialo a abrir en Visitas — usa tu criterio, prioriza que Mapa se vea central en la tab bar).

### 3.11 Reestructuración de navegación de Familia
Rediseña `FamilyRootView` y las vistas relacionadas:
- **Arriba a la izquierda**: acceso al **perfil de familia** (ícono de perfil/avatar). Al tocarlo, abre una vista de perfil que incluya: datos de la familia, código de vinculación (lo que hoy muestra `FamilyManageView` en `codeHero`), y — **dentro de esta vista de perfil** — el botón **"Cerrar sesión"** (sácalo de las toolbars de cada tab, donde está hoy).
- **Arriba a la derecha**: botón/acción para **crear** (publicar solicitud / crear cita), reemplazando el botón "+" que hoy está en `FamilyDashboardView` y el tab "Publicar". Todo lo que se cree (solicitudes, eventos a los que se une, etc.) debe quedar accesible desde aquí, arriba, consistente con el patrón de "Crear evento" del organizador (3.4).
- El tab "Publicar" deja de ser un tab independiente — su contenido (`FamilyPublishView`) se abre desde el botón "crear" de arriba a la derecha (push o sheet).
- Los tabs inferiores resultantes: "Solicitudes" (dashboard de solicitudes/citas — sigue mostrando estados como hoy), "Eventos" (`CommunityEventsView`), "Mi familia" (`FamilyManageView`, ahora sin el `codeHero` que se movió al perfil — o conserva el código ahí también si tiene sentido, pero el logout se mueve sí o sí).
- "Mi familia" pasa a incluir la edición de adultos mayores (ver 3.12).

### 3.12 "Mi familia" — edición de perfil de cada adulto mayor (para IA)
- En `FamilyManageView`, cada `elderlyCard` se vuelve tappable → vista de edición de perfil del adulto mayor con campos:
  - Dirección (ya existe `address`/`neighborhood`).
  - **Edad** (nuevo campo — agrégalo a `elderly_profiles` en backend y a `ElderlySummary`/modelo correspondiente en Swift).
  - **Gustos/intereses** (reutiliza el patrón de `tags` que ya existe para becarios — `tagList`/`tags` en `ElderlySummary`, con UI similar a `tagsSheet` de `StudentHoursView`).
- Backend: `PATCH /families/elderly/:id` (o similar) para actualizar dirección, edad, tags. Solo la familia dueña puede editar (a menos que el control parental de 3.16 indique que el propio adulto mayor también puede).
- Estos datos (dirección, edad, gustos) son el insumo para la IA de recomendación de 3.13.

### 3.13 IA de recomendación para adultos mayores (eventos + conexión con otros adultos mayores)
- Revisa y extiende `Components/AI/HelperRecommender.swift` / `IntentParser.swift` (carpeta nueva sin commitear) para que cubran también:
  - **Recomendación de eventos** al adulto mayor: basada en `tags`/gustos (similitud de tags), cercanía geográfica (lat/lng del adulto mayor vs. evento) y disponibilidad/horario.
  - **Recomendación de conexión con otros adultos mayores**: matching por gustos similares (tags en común), cercanía (radio razonable) y edad similar (rango ±N años, configurable).
- Toda la heurística debe ser local (Swift, sin llamadas externas) — puede vivir en backend también si es más práctico para cruzar datos de todos los usuarios (recomendado: el matching de "personas cercanas con gustos similares" es más eficiente en backend con una query SQL + scoring, expuesto vía `GET /elderly/:id/recommendations` que devuelva eventos sugeridos y perfiles de otros adultos mayores sugeridos).
- **Notificación de match**: cuando se detecta un match de conexión (otro adulto mayor con gustos/cercanía/edad similares), genera una notificación (vía 3.6) **visible únicamente en el perfil del adulto mayor** (no a la familia, salvo lo que dicte el control parental de 3.16 sobre visibilidad).

### 3.14 Sistema de chats (sin APIs externas)
- Si el commit `8726862` ("real-time bidirectional chat") ya trae una base funcional, revísala y verifica que cumpla con:
  - **Adultos mayores entre sí**: chat 1:1 habilitado cuando hay un "match" (de 3.13) o cuando ambas familias/adultos mayores aceptan conectar. Sujeto a control parental (3.16): si la familia desactivó "permitir conocer gente y chatear", el adulto mayor no puede iniciar ni recibir chats nuevos (los existentes pueden quedar visibles en modo solo-lectura o bloquearse también, define el criterio y documenta tu decisión).
  - **Becario ↔ Familia**: chat 1:1 asociado a una `assignment`/solicitud activa, para coordinar detalles del servicio (dirección exacta, instrucciones, etc.).
- Implementación: tabla `chat_threads` (`id`, `type` [`elderly_elderly` | `student_family`], `participant_a_id`, `participant_b_id`, `context_id` nullable [assignment_id o match_id], `created_at`) + tabla `chat_messages` (`id`, `thread_id`, `sender_id`, `body`, `created_at`, `read_at`). Transporte en tiempo real vía el `WebSocketClient`/`socketServer.ts` existente (nuevo canal de eventos `chat:message`, `chat:thread`). Endpoints REST de respaldo: `GET /chats`, `GET /chats/:id/messages`, `POST /chats/:id/messages`.
- UI: nueva pantalla de lista de chats + detalle de conversación, accesible desde el perfil de adulto mayor (chats con otros adultos mayores) y desde el detalle de una asignación/solicitud activa tanto para becario como para familia.

### 3.15 Flujo de servicio en vivo con doble confirmación + review + horas reales (estilo Uber, sin APIs externas)
El backend ya tiene gran parte de esto (`enCamino` → `iniciar` → `confirmarInicio` → `completar`, con `hours_logged` calculado real desde `checkin_at`/`checkout_at`). Falta:
- **Tracking durante el servicio**: cuando el becario va a recoger/llevar al adulto mayor (traslados, ej. "mandados", "citas médicas"), el sistema ya tiene `postLocation`/`getLocations` por rol (`student`/`elderly`). Verifica que:
  - La familia, en `FamilyLiveVisitView`, vea en un mapa en tiempo real la ubicación del becario aproximándose (`role: student`) mientras `status` es `en_camino`/`esperando_confirmacion`/`iniciada`.
  - Si la actividad implica trasladar al adulto mayor, también se debe poder ver/transmitir `role: elderly` durante `iniciada` (seguimiento del adulto mayor en movimiento). Si no existe ya, agrega que el cliente del adulto mayor (o el becario en su nombre, si el adulto mayor no tiene GPS propio) envíe `postLocation` periódicamente durante `iniciada` cuando la actividad sea de traslado.
- **Doble confirmación de finalización**:
  - Hoy `completar` lo dispara solo el becario y cierra todo de inmediato. Cambia el flujo a:
    1. Becario marca "Terminé" → nuevo estado intermedio (ej. `esperando_confirmacion_fin`, agrégalo a `AssignmentStatus` en ambos lados) — **no** cierra ni calcula horas todavía, pero registra `checkout_at` provisional internamente.
    2. Familia (o adulto mayor) ve un aviso/CTA "¿El servicio terminó?" y confirma vía nuevo endpoint `POST /assignments/:id/confirm-completion`.
    3. Al confirmar la familia, **ahí** se ejecuta la lógica actual de `completar` (calcular `hours_logged` real desde `checkin_at` hasta el `checkout_at` registrado en el paso 1 — **usa el tiempo real registrado, no una estimación**, esto ya es consistente con lo que pide el punto: "tome en cuenta el tiempo que estuvo en el servicio no el que agregó como aproximado"), estado pasa a `completada`, se suman las horas a `students.total_hours` y al goal de horas (`StudentHoursView` ya lee de `service_hours`/`hours_logged`, no requiere cambios ahí salvo que el dato llegue correcto).
  - Tras `completada`, dispara la **pantalla de review** (ya existe `ElderlyRatingView` — verifica que se muestre automáticamente tanto al adulto mayor/familia como, si aplica, al becario calificando a la familia/adulto mayor).
- Reflejar el nuevo estado intermedio en `StudentCommitmentsView` (`visitSteps`, `StepProgressBar`, `AssignmentCard.currentStep/actionFooter`) y en las vistas de Familia/Adulto mayor correspondientes.

### 3.16 Control parental (familia → adulto mayor)
- Nuevos flags en `elderly_profiles` (backend) + modelo Swift correspondiente:
  - `allow_social_connections` (bool, default sensato a definir — sugerido `true` pero que la familia pueda desactivarlo): permite que el adulto mayor aparezca en matches/recomendaciones de 3.13 y pueda chatear 1:1 con otros adultos mayores (3.14).
  - `allow_self_profile_edit` (bool): si es `true`, el adulto mayor puede editar su propio perfil (dirección, gustos, etc. desde su propia vista — `ElderlyFamilyView` o donde corresponda); si es `false`, solo la familia puede editar (vía 3.12).
- UI: en la vista de perfil de Familia (la misma de 3.11, arriba a la izquierda, o dentro de "Mi familia" al editar cada adulto mayor de 3.12), agrega los dos toggles por cada adulto mayor vinculado.
- Backend: endpoints de 3.13/3.14 (recomendaciones, chats) y de 3.12 (edición de perfil) deben **verificar estos flags** antes de exponer/permitir la acción correspondiente.

---

## 4. Checklist de entrega
- [ ] Repo sincronizado con los 5 commits nuevos de `origin/main`, sin perder cambios locales (Organizer/, AI/, etc.), con resumen de conflictos y resoluciones documentado.
- [ ] 3.1 — toggle mostrar/ocultar contraseña en registro.
- [ ] 3.2 — catálogo `event_types` en BD + UI con "Otro" para tipo de evento del organizador.
- [ ] 3.3 — mínimo de becarios = 1 en el stepper.
- [ ] 3.4 — "Crear evento" como botón superior, no tab.
- [ ] 3.5 — sección "Becarios" para organizador, con filtro por rating, perfiles completos, y vista de bloqueados con motivo/comentarios.
- [ ] 3.6 — sistema de notificaciones (solicitudes/eventos cercanos + dentro de horario, confirmación sí/no).
- [ ] 3.7 — becario puede cancelar/proponer cambio de horario de su asignación.
- [ ] 3.8 — regla de los 15 minutos para "en camino"/"llegué".
- [ ] 3.9 — límite de adultos mayores en eventos + estado "lleno" (por becarios o por adultos mayores).
- [ ] 3.10 — Mapa al centro de los tabs del becario.
- [ ] 3.11 — navegación de Familia reestructurada (perfil arriba-izq con logout, crear arriba-der).
- [ ] 3.12 — edición de perfil de adultos mayores desde "Mi familia" (dirección, edad, gustos).
- [ ] 3.13 — IA de recomendación de eventos y conexiones para adultos mayores + notificación de match.
- [ ] 3.14 — sistema de chats (adulto↔adulto, becario↔familia), sin APIs externas.
- [ ] 3.15 — doble confirmación de fin de servicio, tracking durante traslado, horas reales, review post-servicio.
- [ ] 3.16 — control parental (permitir conexiones sociales / permitir auto-edición de perfil).
- [ ] Todo compila (`npm run build` en `server`, build del proyecto Xcode) y `npm run dev` levanta el server sin errores.
- [ ] Coherencia visual con PRODUCT.md (warm, accesible, SF Symbols, sin "AI slop").
