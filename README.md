# APEGHaskell

Prototipo de sistema de tipos e intérprete para **APEG** (Adaptable Parsing Expression Grammars).
Basado en: https://github.com/lives-group/APEGHaskell

## ¿Qué es APEG?

APEG es un formalismo donde una gramática puede **extenderse a sí misma durante el parsing**. La idea clave: las reglas reciben la gramática activa como parámetro heredado `g`, y pueden reemplazarla por una versión extendida `g <+: nuevasReglas`.

---

## Setup y compilación

El proyecto está fijado a **GHC 9.6.7** (resolver `lts-22.43`, con `compiler: ghc-9.6.7` en `stack.yaml`). Esa versión es la que tiene soporte de HLS instalado vía ghcup, así que el language server prende en el editor.

```bash
ghcup install ghc 9.6.7   # si no la tienes
stack build
```

> Nota: no uses `system-ghc: true` — el GHC del PATH puede ser otra versión y rompería el match con HLS. Dejá que stack use el `ghc-9.6.7` de ghcup.

---

## Ejecución

```bash
stack exec -- APEGlt muSugar inputSamples/muSugar/SimpleCMD.txt
```

Opciones:
- `-l` — lista los lenguajes disponibles
- `-a` — solo informa ACCEPTED / REJECTED
- `-d` — imprime el contexto de tipos después de ejecutar

Ejemplo de salida:

```
prog
├─ block
│  ├─ {
│  ├─ stmt
│  │  ├─ read(
│  │  ├─ x
│  │  ├─ )
│  │  ├─ ;
│  ├─ }
ACCEPTED
```

---

## Estructura del proyecto

```
src/APEG/
├── AbstractSyntax.hs          -- Tipos: APeg, Expr, Type, ApegRule, ApegGrm
├── DSL.hs                     -- Helpers para construir gramáticas (usar esto)
├── TypeSystem.hs              -- Verificación de tipos
├── PlayGround.hs              -- runGrammar, acceptTest, runFile
├── Interpreter/
│   ├── APEGInterp.hs          -- Intérprete principal
│   └── State.hs               -- Estado del intérprete (PureState)
└── ASTSamples/
    └── MicroSugar.hs          -- Gramática completa de μSugar (REFERENCIA PRINCIPAL)

src/inputSamples/              -- Archivos de prueba (.txt) para el intérprete
```

---

## Gramática base: μSugar

Definida en `MicroSugar.hs`. Incluye:

| Construcción | Sintaxis |
|---|---|
| Asignación | `x := expr;` |
| Lectura | `read(x);` |
| Impresión | `print(expr);` |
| Condicional | `if(cexpr) block` |
| Bucle | `loop(cexpr) block` |
| Bloque | `{ stmt* }` |

---

## Extensiones existentes (en `src/inputSamples/`)

Las extensiones se definen **dentro del lenguaje μSugar** usando `define nombre { reglas }` y se activan con `syntax nombre { ... }`.

### `pair` — literales de pares
```
define pair {
   fator -> "(" whites expr whites "," whites expr whites ")";
}
syntax pair {
   x := (2,1) + (1,2);
}
```

### `foreach` — bucle iterador
```
define foreach {
   stmt -> whites "foreach(" whites identifier whites ":" whites expr whites ")" block ;
}
syntax foreach {
   foreach( i : x) { y := i + 10; }
}
```

### `query` / SQL — consultas embebidas
```
define query {
   stmt   -> whites identifier whites "<--?" whites SQLexp whites ";";
   SQLexp -> "SELECT" whites1 fieldList whites1 "FROM" whites1 identifier ...;
}
syntax query {
   x <--? SELECT * FROM table;
}
```

---

## Convenciones del DSL (para escribir extensiones en Haskell)

```haskell
-- Combinadores de PEG
seqs [p1, p2, p3]       -- secuencia
alts [p1, p2, p3]       -- alternativa (ordered choice)
star p                   -- Kleene *
star1 p                  -- Kleene + (uno o más)
lit "texto"              -- literal
whts                     -- whitespace*
identifier               -- lower (lower|digit)*
call "nt" [g] []         -- llamada a no-terminal

-- Bind y update
"x" .=. peg             -- captura lo que parsea peg en variable x
"x" .<. expr            -- asigna expresión a variable x

-- Tipos
tLang, tStr, tInt, tGrm, tMAPeg

-- Atributo gramática
g  -- = EVar "g"
```

---

## Extensiones nuevas en Haskell

Definidas en `src/APEG/ASTSamples/Extensions.hs`, directamente como reglas Haskell (no vía `define`/`syntax`). Se fusionan con la gramática base con `joinRules`, formando `microSugarExt`. **No fue necesario modificar ningún archivo existente.**

### `repeat...until` — bucle do-while

```
repeat { ... } until ( cexpr ) ;
```

```haskell
ruleRepeatUntil = rule "stmt" ["g" .:: tLang] []
  (seqs [ whts, lit "repeat", call "block" [g] [],
          whts, lit "until", whts, lit "(", whts,
          call "cexpr" [g] [], whts, lit ")", whts, semic ])
```

### `unless` — condicional negado

```
unless ( cexpr ) { ... }
```

```haskell
ruleUnless = rule "stmt" ["g" .:: tLang] []
  (seqs [ whts, lit "unless", whts, lit "(", whts,
          call "cexpr" [g] [], whts, lit ")", call "block" [g] [] ])
```

### Cómo correrlo

No hay CLI (el `Main.hs` es un stub). Se prueba desde GHCi con los runners del módulo:

```bash
printf 'import APEG.ASTSamples.Extensions\nrunExt "src/inputSamples/testExtension.txt"\n' | stack ghci
```

Runners disponibles: `runExt` (árbol + ACCEPTED), `acceptExt` (solo True/False), `debugExt` (contexto de tipos). El valor `microSugarExt` exporta la gramática fusionada por si se quiere reusar.

Archivo de prueba: `src/inputSamples/testExtension.txt`.

---

## Notas de implementación (por qué funciona así)

Esta sección explica el *fondo*, no solo el *qué*.

### 1. Por qué las reglas se llaman `"stmt"` con la misma firma, y qué hace `joinRules`

Una gramática APEG es, literalmente, **una lista de valores `ApegRule`**. Cada regla tiene: nombre (el no-terminal), atributos heredados (`inh`, acá `["g" .:: tLang]`), atributos sintetizados (`syn`, acá `[]`) y un cuerpo (el `APeg`).

`joinRules base [r1, r2, ...]` recorre la lista nueva y para cada regla llama a `grmAddRule` (ver `AbstractSyntax.hs:148`). `grmAddRule` busca en la base una regla con el **mismo nombre**:

- **Mismo nombre + misma firma** (inh y syn idénticos) → reemplaza el cuerpo por `Alt cuerpoViejo cuerpoNuevo`. Es decir, **agrega una alternativa** (ordered choice) a la regla existente.
- **Mismo nombre + firma distinta** → `error` (conflicto: no sabe cómo combinarlas).
- **Nombre nuevo** → la agrega como regla aparte.

Por eso nombramos nuestras reglas `"stmt"` con exactamente la misma firma que la `stmt` original. El efecto es que la `stmt` resultante queda así:

```
Alt (Alt stmtOriginal repeatUntil) unless
```

Cuando el parser llega a `stmt`, prueba primero las alternativas originales (`print`, `read`, `if`, `loop`, asignación) y, si todas fallan, prueba `repeat` y luego `unless`. Como cada una empieza con una palabra clave distinta, no hay ambigüedad aunque el orden importe (PEG es *ordered choice*: la primera alternativa que matchea gana).

Si hubiéramos cambiado la firma (p. ej. agregar un atributo), `grmAddRule` habría tirado error en vez de fusionar — por eso la firma tiene que calzar al pie de la letra.

### 2. Por qué hay que poner `whts` explícito antes de `cexpr` (PEG vs. compilador con lexer)

En un compilador tradicional hay **dos fases**: un *lexer* (tokenizer) parte el texto en tokens y, de paso, **se come los espacios automáticamente**; luego el *parser* trabaja sobre tokens y ni se entera de los espacios.

PEG (y APEG) es **scannerless**: no hay lexer separado. La gramática trabaja **directo sobre caracteres**. Eso significa que el whitespace es parte de la gramática y hay que consumirlo a mano en cada lugar donde puede aparecer.

`cexpr` y `fator` arrancan matcheando caracteres significativos (un identificador, un número, un `(`); **no saltan espacios al inicio**. Entonces si después de `lit "("` el input es `( x = 1 )`, el espacio tras el paréntesis queda sin consumir y `fator` falla, porque un espacio no es ni identificador, ni número, ni `(`. Ese fue exactamente el bug inicial.

La solución es intercalar `whts` (cero o más espacios) donde semánticamente puede haber espacios: después de `(`, antes de `)`, entre la palabra clave y el `(`, etc. Por eso también escribimos `lit "until", whts, lit "("` en lugar de `lit "until("`: así toleramos `until(`, `until (`, `until  (`, etc.

Esto es más verboso que con un lexer, pero a cambio da **control total** sobre los espacios — podrías hacer lenguajes whitespace-sensitive sin trucos.

### 3. Por qué no hubo que tocar ningún archivo existente

Porque extender la gramática es **composición de valores, no mutación de código**. `microSugar` es un valor inmutable (una lista de reglas). Para extenderlo no parcheamos su definición: producimos una lista **nueva**:

```haskell
microSugarExt = joinRules microSugar [ruleRepeatUntil, ruleUnless]
```

`microSugar` queda intacto; `microSugarExt` es otra gramática construida combinándolo con reglas extra. Esta es la promesa central de APEG: **las extensiones del lenguaje son datos de primera clase que se combinan**, no modificaciones al parser.

Comparalo con un parser hecho a mano o generado (yacc/ANTLR): ahí, para agregar una construcción, tendrías que editar el archivo de gramática y regenerar el parser. Acá la "extensión" es solo otro valor que se compone con `joinRules`. (Y de hecho μSugar lleva esto aún más lejos: con `define`/`syntax` permite componer gramáticas **en tiempo de ejecución**, durante el propio parsing. Nosotros hicimos lo mismo pero en tiempo de compilación de Haskell — las dos caras de la misma idea.)

### 4. ¿`repeat...until` es "azúcar sintáctico"?

"Azúcar sintáctico" = una construcción que **no agrega poder expresivo**; es una forma más cómoda de escribir algo ya expresable, que conceptualmente se podría *desazucarar* (reescribir) a la forma base.

Primero, un detalle clave de este proyecto: el intérprete de μSugar es un **reconocedor** (parser). Construye el árbol de derivación y dice ACCEPTED/REJECTED; **no ejecuta** los programas (no hay evaluación real del `loop`, ni estado de variables en runtime). Nuestras reglas definen solo la **sintaxis** (cómo se parsea), no la **semántica** (qué hace). Así que, estrictamente, ambas extensiones son "puramente sintácticas" en el sentido de que solo agregan formas reconocibles.

Dicho eso, si miramos el *significado intencionado*:

- **`unless`** es el caso clásico de azúcar: `unless(c) B` significa lo mismo que `if(¬c) B`. No aporta poder nuevo, solo legibilidad. Es azúcar puro.
- **`repeat...until`** es más sutil. Un do-while ejecuta el cuerpo **una vez antes** de evaluar la condición; un `loop` (while) la evalúa **antes** de la primera iteración. Por eso `repeat` **no** se reduce trivialmente a `loop`: para desazucararlo de verdad tendrías que escribir "ejecutar el cuerpo una vez; luego un while" — es decir, requiere reordenar la evaluación. Si μSugar tuviera semántica de ejecución, `repeat...until` sería *menos* azúcar que `unless`, porque introduce un patrón de control que no es una mera reescritura local de `loop`.

Conclusión honesta: en **este** contexto (un parser sin ejecución), las dos son extensiones sintácticas. Si el lenguaje tuviera semántica, `unless` seguiría siendo azúcar puro, mientras que `repeat...until` estaría en el límite — expresable en términos de while, pero solo a costa de duplicar/reordenar el cuerpo.
