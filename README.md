# APEGHaskell

Prototipo de sistema de tipos e intérprete para **APEG** (Adaptable Parsing Expression Grammars).
Basado en: https://github.com/lives-group/APEGHaskell

## ¿Qué es APEG?

APEG es un formalismo donde una gramática puede **extenderse a sí misma durante el parsing**. La idea clave: las reglas reciben la gramática activa como parámetro heredado `g`, y pueden reemplazarla por una versión extendida `g <+: nuevasReglas`.

---

## Setup y compilación

```bash
# Requiere GHC 9.4.8 y Stack
ghcup install ghc 9.4.8
stack setup
stack build
```

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

## Tarea: nueva extensión en Haskell

**Objetivo:** agregar 1-2 extensiones a μSugar definidas directamente en Haskell (igual que `MicroSugar.hs`), sin modificar archivos existentes.

**Archivo a crear:** `src/APEG/ASTSamples/Extensions.hs`

El patrón a seguir (tomando `foreach` como referencia):

```haskell
ruleForEach :: ApegRule
ruleForEach = rule "stmt"
                   ["g" .:: tLang]
                   []
                   (seqs [whts, lit "foreach(", whts, identifier, whts,
                          lit ":", whts, call "expr" [g] [], whts,
                          lit ")", whts, call "block" [g] []])
```

**Extensiones candidatas:**

| Extensión | Sintaxis | Dificultad |
|---|---|---|
| `repeat...until` | `repeat block until( cexpr );` | Baja |
| `unless` | `unless( cexpr ) block` | Baja |
| `switch/case` | `switch(expr){ case valor: block }` | Media |
| `let...in` | `let id := expr in block` | Media |

Para activar la extensión en la gramática base se usa `joinRules` o `grmAddRule` sobre `microSugar` (ver `AbstractSyntax.hs:144`).

**Archivo de prueba a crear:** `src/inputSamples/testExtension.txt`
