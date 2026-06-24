# HACER — Entender el código del intérprete APEG

> **Nota para Claude (cuando abra este repo):** este archivo es un pendiente.
> El usuario (Rolando) ya terminó la extensión de VS Code (Proyecto 2, repo
> `../mysugar-extension`). Ahora quiere **entender el código Haskell** de este repo
> para poder defenderlo en la exposición. El plan acordado: usar esta guía de lectura
> y luego **trazar juntos, paso a paso, el ejemplo `{ x := 5; }`** por el intérprete,
> explicándole cada salto. Empezar por ahí cuando retomemos.

---

## Cómo leer Haskell (es distinto a C++/Python)

1. **Lee los TIPOS antes que el cuerpo.** La firma `f :: A -> B -> C` dice el 80%
   de lo que hace la función. Pregúntate "qué entra y qué sale" antes de la lógica.
2. **Usa GHCi como lupa:** `stack ghci`, luego:
   - `:t interpGrammar` → su tipo
   - `:i APeg` → lista todos los constructores de un tipo
   - corre funciones con ejemplos para ver qué devuelven
3. **Usa HLS en el editor:** hover para ver tipos, "go to definition" para saltar.
4. **No leas línea por línea.** Agarra UN ejemplo y SÍGUELO por el sistema.

---

## Orden de lectura (de mayor a menor importancia)

### 🥇 1. `src/APEG/AbstractSyntax.hs` — el vocabulario (EMPEZAR AQUÍ)
Define qué ES una gramática. Las 3 claves:
- `type ApegGrm = [ApegRule]` → una gramática es **una lista de reglas**.
- `data APeg = Lit | NT | Kle | Not | Seq | Alt | Bind | ...` → las construcciones
  PEG (literal, no-terminal, Kleene, negación, secuencia, alternativa…). Todo se arma
  con estas.
- `joinRules` / `grmAddRule` (al final) → **cómo se componen/extienden gramáticas**.
  Base de toda la extensibilidad APEG (y de las extensiones `repeat`/`unless`).

### 🥈 2. `src/APEG/ASTSamples/MicroSugar.hs` — los tipos EN USO
La gramática μSugar real escrita con esos tipos. Puente teoría→práctica: reconocer
`Seq`, `Alt`, `NT` formando reglas `stmt`, `expr`, `block`. Comparar una regla con su
construcción en AbstractSyntax.

### 🥉 3. `src/APEG/PlayGround.hs` — el punto de entrada (top-down)
Corto (58 líneas). `runGrammar` es de donde arranca todo. Seguir hacia adentro.

### 4. `src/APEG/Interpreter/APEGInterp.hs` — el motor (el corazón)
`interpGrammar` y cómo recorre cada constructor `APeg`. La parte más densa: abrir
DESPUÉS de entender los tipos. Buscar cómo maneja cada caso de `APeg`.

### 5. Apoyo (leer por necesidad, no de corrido)
- `Interpreter/State.hs` y `Interpreter/DT.hs` → el estado y el resultado.
- `Interpreter/MonadicState.hs` → la mónada `APegSt` (carga el estado).
- `TypeSystem.hs`, `Combinators.hs`, `DSL.hs` → cuando un detalle lo pida.
- `Parser/*.hs` → solo para entender cómo se parsea el TEXTO de `define/syntax`.

---

## Ejercicio práctico (lo que MÁS sirve)

Trazar el programa más simple `{ x := 5; }`:
1. Entra por `runGrammar microSugar [] "{ x := 5; }"` (PlayGround).
2. El intérprete arranca en la regla `prog` → llama a `block` → `block` llama a
   `stmt` → `stmt` reconoce la asignación.
3. Meter `Debug.Trace.trace` o leer qué constructores `APeg` se van disparando.

Cuando pueda explicar ese recorrido, entiende el núcleo del intérprete.

---

## Contexto rápido del proyecto (recordatorio)

- Núcleo: intérprete/reconocedor APEG en Haskell (este repo). Gramática base
  `microSugar`, extendida `microSugarExt` (repeat/until, unless en `Extensions.hs`).
- Bonus ya hecho: extensión VS Code en `../mysugar-extension` (5/5 features).
- CLI: `stack exec -- APEGLitleToy-exe [--base] <archivo>` (lo agregamos en `app/Main.hs`).
- Pendiente opcional aparte de esto: posición exacta de errores de sintaxis
  (requiere rastrear "farthest failure" en el intérprete).
