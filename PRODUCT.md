# Product

## Register

product

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

1. **El adulto mayor manda el piso de accesibilidad**: si la pantalla la ve un adulto mayor, tipografía ≥ body grande, contraste ≥4.5:1, un CTA por pantalla.
2. **Nativo primero**: SF Symbols, componentes de sistema (List, Form, ContentUnavailableView), haptics estándar. La app debe sentirse de Apple, no de plantilla web.
3. **El teal es la firma**: #167B70 ancla la identidad. Roles se distinguen por tinte (teal familia, verde becario, naranja adulto mayor) pero el teal es la voz de la marca.
4. **Motion comunica estado**: 150–250ms, ease-out. La única excepción coreografiada es la apertura de la app (splash→login, ~1.2s). Reduce Motion siempre respetado.
5. **Confianza visible**: estados en vivo (GPS, websocket), verificación, y progreso siempre a la vista — la confianza entre extraños es el producto.

## Accessibility & Inclusion

- Prioridad alta: Dynamic Type en todas las pantallas, contraste ≥4.5:1, targets ≥44pt.
- `accessibilityReduceMotion` respetado en toda animación.
- VoiceOver: iconos decorativos ocultos, elementos combinados con labels en español.
