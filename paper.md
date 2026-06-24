# 1. Introducción a los Lenguajes Extensibles (APEG)

### ¿Qué es un Lenguaje Extensible?

Un **lenguaje extensible** es aquel que tiene la capacidad de **extender su propia sintaxis y semántica** mediante construcciones internas. Esta idea no es nueva; tiene sus raíces en lenguajes antiguos como **Lisp** y sus derivados (Scheme, Racket).

Hoy en día, el objetivo es revivir esta filosofía a través de la **programación orientada a lenguajes**, permitiendo que los usuarios utilicen librerías externas (eDSLs) para añadir piezas de sintaxis nuevas a su lenguaje base de forma sencilla.

### Requisitos para un lenguaje adaptable

Para que un lenguaje se considere verdaderamente adaptable o extensible, debe cumplir tres condiciones:

1. **Sintaxis base clara:** Debe tener un conjunto de reglas gramaticales iniciales bien definidas.
2. **Sin herramientas externas:** El usuario debe poder incrementar o añadir nuevas reglas gramaticales de manera elegante, sin necesidad de usar programas o generadores de parsers adicionales.
3. **Activación flexible:** El programador debe poder **activar y combinar** estas nuevas sintaxis justo cuando las necesite dentro de su código.

### Los desafíos y conflictos

Hacer que un lenguaje aprenda nuevas reglas "sobre la marcha" no es fácil. Al introducir sintaxis arbitraria, pueden surgir **conflictos**. Por ejemplo, una regla nueva podría "pisar" a una vieja (predominar) o generar ambigüedad sobre qué regla aplicar primero. Las gramáticas APEG resuelven esto usando el modelo de las **PEG** (Gramáticas de Expresiones de Análisis Sintáctico), que usan una **elección priorizada** (si la primera regla encaja, no se mira la segunda).

---

### El lenguaje de ejemplo: $\mu Sugar$

Para demostrar estos conceptos, los autores crearon un lenguaje pequeño llamado **$\mu Sugar$**. Su estructura básica sigue un orden específico:

- **Declaraciones de sintaxis (`newSyn`):** El programa comienza definiendo las nuevas reglas gramaticales mediante la palabra clave `define`.
- **Bloques de código:** Después de las definiciones, siguen los bloques de sentencias, que pueden ser de dos tipos:
    - **Bloques base (`block`):** Usan solo las reglas estándar del lenguaje (como asignaciones o `print`).
    - **Bloques extendidos (`extBlock`):** Comienzan con la palabra clave `syntax` seguida del nombre de la regla que se quiere activar.

**Punto clave sobre el Ámbito (Scope):** Una de las cosas más importantes de $\mu Sugar$ es que la nueva sintaxis solo funciona **dentro de su bloque `syntax`**. Una vez que el bloque termina, esa regla deja de existir para el parser, lo que permite combinar diferentes extensiones en distintas partes del programa sin que se estorben entre sí.

---

### Fundamentos Técnicos (PEG y APEG)

- **Basado en PEG:** Las extensiones de sintaxis se escriben usando las mismas construcciones que las **Parsing Expression Grammars (PEG)**.
- **Adaptabilidad (APEG):** A diferencia de las gramáticas normales que son estáticas, las **Adaptable PEGs (APEG)** formalizan cómo la gramática cambia dinámicamente, modelando cómo se buscan y aplican las nuevas reglas durante el análisis.
- **Implementación en Haskell:** El paper explica cómo usar **mónadas de estado** y combinadores en Haskell para que el parser pueda llevar el rastro de estas reglas nuevas y el texto consumido al mismo tiempo.

# 📖 Capítulo 2 — Semántica de las Expresiones de Parsing (APEG)

## 🔤 Notaciones Matemáticas Base

### Secuencias `x̄`

Una letra con barrita encima significa "lista de ese elemento".

```
x̄  = [3, 7, 2, 9]        ← lista de elementos
x̄⁴ = lista de 4 elementos exactamente
x̄² = lista de 2 elementos exactamente
```

### Mapeos finitos `σ` (el diccionario)

Un mapeo es un diccionario que asocia claves con valores. Se usa `σ` (sigma) como nombre genérico.

```
σ = { "x"/10, "y"/25, "nombre"/"Juan" }

σ("x")     → devuelve 10
σ("y")     → devuelve 25
σ("z")     → devuelve ⊥  (no existe, indefinido)
σ["x"/99]  → { "x"/99, "y"/25, "nombre"/"Juan" }  (actualización, solo cambia x)
```

### El entorno `Θ` (theta) — la memoria del parser

Es un par que carga **dos cosas a la vez**:

- `V` → diccionario de variables y sus valores actuales
- `Γ` (gamma) → diccionario de tipos de cada variable

```
V = { "x"/10, "nombre"/"Juan" }     ← valores reales
Γ = { "x"/Int, "nombre"/String }    ← solo los tipos

Θ = ⟨V, Γ⟩   ← ambos juntos = la memoria completa del parser
```

> **Importante:** El texto de entrada y las variables del programa son cosas separadas. Las variables son lo que el programador declaró. El texto es lo que el parser está leyendo.

### La notación central `(Θ, p) ⇝w z ⊳ Θ'`

Esta es la firma de toda la semántica. Se lee:

> _"Usando el entorno Θ, la expresión p procesa el texto w, consume el prefijo z, y produce un nuevo entorno Θ'"_

|Símbolo|Qué representa|
|---|---|
|`Θ`|Entorno **antes** de parsear|
|`p`|La regla/expresión que se aplica|
|`w`|El texto de entrada completo|
|`z`|El pedazo de texto que se consumió|
|`Θ'`|Entorno **después** de parsear|
|`⊥`|En lugar de `z` significa que el parsing **falló**|

---

## 📋 Las 8 Reglas de Semántica

### Regla 1: Empty `λ`

> _"Siempre tiene éxito pero no consume nada del texto."_

```
Θ  = ⟨ {"x"/5}, {"x"/Int} ⟩
p  = λ
w  = "hola"
─────────────────────────────
z  = ""      ← consumió NADA
Θ' = Θ       ← entorno no cambió
```

**¿Para qué sirve?** Como caso base en reglas más complejas. Dice "si no hay nada que reconocer, está bien igual".

---

### Regla 2: Term `a`

> _"Reconoce un carácter específico del texto."_

**Caso exitoso:**

```
p  = reconocer "h"
w  = "hola"
─────────────────────────────
z  = "h"     ← consumió la "h"
Θ' = Θ       ← entorno no cambió
             ← texto pendiente: "ola"
```

**Caso fallido — carácter no coincide:**

```
p  = reconocer "z"
w  = "hola"
─────────────────────────────
z  = ⊥       ← falla, "hola" no empieza con "z"
```

**Caso fallido — texto vacío:**

```
p  = reconocer "h"
w  = ""
─────────────────────────────
z  = ⊥       ← falla, no hay nada que leer
```

> **Nota:** En Empty y Term el entorno Θ nunca cambia porque solo leen texto, no guardan nada en variables.

---

### Regla 3: Seq `p1 . p2`

> _"Aplica p1 primero, y si tiene éxito, aplica p2 sobre lo que quedó."_

**Caso exitoso:**

```
p1 = reconocer "h"
p2 = reconocer "o"
w  = "hola"
─────────────────────────────
p1 consume "h" → queda "ola"
p2 consume "o" → queda "la"
z  = "ho"
Θ' = Θ
```

**Caso fallido:**

```
p1 = reconocer "h"
p2 = reconocer "i"
w  = "hola"
─────────────────────────────
p1 consume "h" → queda "ola"
p2 intenta "i" en "ola" → falla ✗
z  = ⊥
```

> **⚠️ Regla de oro — Rollback:** Si p1 o p2 fallan, **cualquier cambio al entorno se descarta** y vuelve al Θ original. Es como un rollback en una base de datos — o todo funciona junto, o nada se guarda.

```
Θ  = ⟨ {"x"/0}, {"x"/Int} ⟩
p1 = reconocer "h" y guardar en x → éxito, Θ' = {"x"/"h"}
p2 = reconocer "z"                → falla ✗
─────────────────────────────────────────────────────────────
resultado: z = ⊥,  Θ vuelve a {"x"/0}  ← se descartó el cambio
```

---

### Regla 4: Choice `p1 / p2`

> _"Intenta p1 primero. Si funciona, listo. Solo si p1 falla, intenta p2."_

**Caso 1 — p1 funciona, p2 ni se mira:**

```
p1 = reconocer "h"
p2 = reconocer "m"
w  = "hola"
─────────────────────────────
p1 éxito → consume "h"
p2 se ignora completamente
z  = "h"
```

**Caso 2 — p1 falla, se intenta p2:**

```
p1 = reconocer "z"
p2 = reconocer "h"
w  = "hola"
─────────────────────────────
p1 falla con "hola" ✗
se resetea el texto a "hola"
p2 éxito → consume "h" ✓
z  = "h"
```

**Caso 3 — ambos fallan:**

```
p1 = reconocer "z"
p2 = reconocer "m"
w  = "hola"
─────────────────────────────
p1 falla ✗, p2 falla ✗
z  = ⊥
```

> **¿Por qué es diferente a gramáticas normales (CFG)?** En CFG el parser podría probar ambas opciones al mismo tiempo generando ambigüedad. En PEG/APEG la elección es **determinista y ordenada** — si p1 funciona, p2 nunca se evalúa. No hay ambigüedad posible. Por eso se llama **elección priorizada**.

---

### Regla 5: Star `p*`

> _"Aplica p una y otra vez hasta que falle. Cuando falle, para y devuelve todo lo que consumiste."_

```
p  = reconocer "a"
w  = "aaab"
─────────────────────────────
intento 1: consume "a" → queda "aab" ✓
intento 2: consume "a" → queda "ab"  ✓
intento 3: consume "a" → queda "b"   ✓
intento 4: intenta "a" → encuentra "b" ✗ falla
─────────────────────────────────────────────
z  = "aaa"   ← todo lo consumido antes de fallar
Θ' = Θ       ← el fallo del último intento se descarta
```

**Con variables:**

```
Θ  = ⟨ {"x"/0}, {"x"/Int} ⟩
p  = reconocer "a" y sumarle 1 a x
w  = "aab"
─────────────────────────────────────
intento 1: consume "a", x = 1 ✓
intento 2: consume "a", x = 2 ✓
intento 3: intenta "a", encuentra "b" ✗
           → se descarta x = 3, vuelve a x = 2
─────────────────────────────────────────────
z  = "aa"
Θ' = ⟨ {"x"/2}, {"x"/Int} ⟩
```

> **⚠️ Star siempre tiene éxito** — cero repeticiones es válido, nunca devuelve ⊥. Si quieres al menos una repetición, usas `p+` que es simplemente `p . p*`.

---

### Regla 6: Not-predicate `!p`

> _"Mira hacia adelante sin consumir nada. Si p falla → !p gana. Si p funciona → !p falla."_

**Caso exitoso — p falla entonces !p gana:**

```
p  = reconocer "z"
w  = "hola"
─────────────────────────────
p  intenta "z" en "hola" → falla ✗
!p dice "perfecto, eso quería" → éxito ✓
z  = ""      ← no consumió nada
w  sigue siendo "hola" intacto
```

**Caso fallido — p funciona entonces !p falla:**

```
p  = reconocer "h"
w  = "hola"
─────────────────────────────
p  reconoce "h" → éxito ✓
!p dice "no quería eso" → falla ✗
z  = ⊥
w  vuelve a "hola"  ← se resetea
```

> **⚠️ Diferencia especial con Seq y Star:** Cuando algo falla en Seq y Star el entorno se descarta. Pero en Not-predicate el entorno **sí se conserva** aunque falle, porque sirve como lookahead para calcular información útil que se necesita después.

**Uso práctico — distinguir palabras reservadas de identificadores:**

```
regla identificador = !("while") reconocer_letras

w = "while"  → !("while") falla → no es identificador ✓
w = "miVar"  → !("while") éxito → sí es identificador ✓
```

Sin consumir nada, el parser ya sabe qué esperar.

---

### Regla 7: Bind `ϑ = p` y Update `ϑ ← e`

#### Update `ϑ ← e`

> _"Evalúa la expresión e y guarda el resultado en la variable ϑ. No consume texto."_

```
Θ  = ⟨ {"x"/0}, {"x"/Int} ⟩
p  = x ← 5+3
w  = "hola"
─────────────────────────────
z  = ""      ← no consumió nada del texto
Θ' = ⟨ {"x"/8}, {"x"/Int} ⟩   ← x ahora vale 8
```

#### Bind `ϑ = p`

> _"Aplica la regla p, y el texto que p consuma lo guarda en la variable ϑ."_

```
Θ  = ⟨ {"x"/"nada"}, {"x"/String} ⟩
p  = reconocer "hol"
ϑ  = x
w  = "hola"
─────────────────────────────────────
p  consume "hol"
z  = "hol"
Θ' = ⟨ {"x"/"hol"}, {"x"/String} ⟩  ← x guarda lo que se leyó
```

**Si Bind falla, no guarda nada:**

```
Θ  = ⟨ {"x"/"nada"}, {"x"/String} ⟩
p  = reconocer "z"
w  = "hola"
─────────────────────────────────────
p  falla ✗
z  = ⊥
Θ' = Θ   ← x sigue siendo "nada"
```

**Diferencia clave:**

||Update `ϑ ← e`|Bind `ϑ = p`|
|---|---|---|
|¿Qué guarda?|Resultado de una expresión|Texto consumido por una regla|
|¿Consume texto?|No|Sí|
|Ejemplo|`x ← 5+3` guarda `8`|`x = reconocer "hol"` guarda `"hol"`|

**Usados juntos en un ejemplo real:**

```
Θ  = ⟨ {"num"/0}, {"num"/Int} ⟩
w  = "42abc"

paso 1 — Bind:   num = reconocer_digitos  → num guarda "42"  (texto)
paso 2 — Update: num ← convertir(num)    → num guarda 42    (entero)
──────────────────────────────────────────────────────────────────────
z  = "42"
Θ' = ⟨ {"num"/42}, {"num"/Int} ⟩
texto pendiente = "abc"
```

Bind captura el texto, Update lo procesa. Se usan mucho juntos.

---

### Regla 8: Non-terminal call `A e ϑ`

> _"Llama a una regla por su nombre A, pasándole parámetros e, y guardando los resultados en ϑ."_

**Los componentes de la llamada:**

```
A e ϑ
│ │ │
│ │ └── donde guardar el resultado
│ └──── parámetros (el primero siempre es el atributo lenguaje g)
└────── nombre del no-terminal
```

**El atributo lenguaje `g`** es un diccionario de reglas gramaticales:

```
g = {
    "stmt"   → regla para sentencias,
    "expr"   → regla para expresiones,
    "numero" → regla para números
}
```

**Ejemplo paso a paso:**

```
Θ  = ⟨ {"g"/ {"stmt"→reglaStmt, "expr"→reglaExpr} }, ... ⟩
w  = "x := 10"
llamada = stmt [g] [resultado]

Paso 1 — evalúa parámetros:  g → obtiene el diccionario de reglas
Paso 2 — busca la regla:     "stmt" en g → encuentra reglaStmt
Paso 3 — aplica la regla:    reglaStmt procesa "x := 10" → éxito ✓
Paso 4 — guarda resultado:   Θ' = Θ con resultado actualizado
```

**¿Por qué esto hace a APEG dinámico?** En PEG normal las reglas son fijas, siempre las mismas. En APEG puedes pasarle diferentes diccionarios a la misma llamada:

```
stmt [g_base]                    ← solo reglas base
stmt [g_base + g_for + g_sql]   ← base + extensiones
```

El mismo no-terminal `stmt` se comporta diferente dependiendo del diccionario que recibe.

**Conexión con μSugar:**

```
syntax sfor {          ← activa extensión sfor dentro del bloque
    for x := 0 ...
}                      ← aquí termina, sfor deja de existir

-- lo que pasa internamente:
dentro del bloque  → stmt [g_base + g_sfor] [r]
fuera del bloque   → stmt [g_base] [r]
```

---

## 🔑 Por qué las extensiones no van en la base

|Razón|Explicación|
|---|---|
|**Modularidad**|No todos los programas necesitan todas las extensiones|
|**Conflictos**|Tener todo activo siempre genera conflictos entre reglas|
|**Filosofía**|La base la define el creador del lenguaje, las extensiones las crea cualquiera como librerías|

```
-- igual que en Python:
import pandas        ← solo cuando necesitas datos
import matplotlib    ← solo cuando necesitas gráficas
-- no vienen en la base porque no todos las necesitan
```

---

## 📊 Resumen de las 8 Reglas

| #   | Regla        | Símbolo       | Idea central                               | ¿Cambia Θ?            | ¿Puede fallar? |
| --- | ------------ | ------------- | ------------------------------------------ | --------------------- | -------------- |
| 1   | Empty        | `λ`           | Siempre éxito, no consume nada             | No                    | No             |
| 2   | Term         | `a`           | Consume un carácter específico             | No                    | Sí             |
| 3   | Seq          | `p1.p2`       | Todo o nada, rollback si falla             | Solo si éxito         | Sí             |
| 4   | Choice       | `p1/p2`       | Prioridad al primero, determinista         | Solo si éxito         | Sí             |
| 5   | Star         | `p*`          | Repite hasta fallar, nunca falla           | Solo si éxito         | No             |
| 6   | Not          | `!p`          | Centinela, no consume, conserva Θ          | Conserva aunque falle | No             |
| 7   | Bind/Update  | `ϑ=p` / `ϑ←e` | Captura texto / asigna valores             | Sí si éxito           | Bind sí        |
| 8   | Non-terminal | `A e ϑ`       | Llama reglas dinámicamente con diccionario | Sí                    | Sí             |

# 📖 Capítulo 3 — Semántica del Lenguaje de Atributos

## ¿Qué es el "lenguaje de atributos"?

Recuerda del capítulo 2 que las reglas APEG pueden recibir parámetros y devolver resultados — esas son las **variables/atributos**. El **lenguaje de atributos** es básicamente el mini-lenguaje de expresiones que vive _dentro_ de las reglas APEG para computar esos valores.

En la sintaxis abstracta del capítulo 2 (Fig. 3), ese lenguaje estaba representado por `e`, `m`, `mp`, `me`, `mt` pero no se explicó. Este capítulo lo formaliza.

La notación que se usa es `(Θ, e) ~> v`, que se lee:

> _"Evaluando la expresión `e` en el entorno `Θ`, obtenemos el valor `v`"_

Es casi igual a la notación del capítulo 2 pero en vez de consumir texto, solo **calcula un valor**.

---

## Los valores semánticos

Primero hay que saber qué tipos de valores existen:

|Valor|Qué representa|
|---|---|
|`VStr`|Un string|
|`VInt`|Un entero|
|`VBool`|Un booleano|
|`VMap`|Un mapa (diccionario) de strings a valores|
|`VGrm`|Una **gramática** — colección de reglas construidas dinámicamente|
|`VLan`|Un **lenguaje** — gramática que ya fue type-checkeada|
|`VPeg`|Un AST de una expresión PEG|
|`VExp`|Un AST de una expresión|
|`VType`|Un AST de un tipo|

Los últimos tres (`VPeg`, `VExp`, `VType`) son los más nuevos — son valores cuyo contenido es **código APEG representado como dato**. Eso es lo que permite construir reglas dinámicamente.

La distinción clave que vas a ver mucho:

- **`VGrm` (gramática)** → colección de reglas, _sin verificar_
- **`VLan` (lenguaje)** → gramática que pasó el type-checker + su contexto de tipos

---

## Los Meta-operadores — construir reglas como valores

Aquí está la idea más importante del capítulo. En PEG normal escribes `p1 . p2` y eso _parsea_ una secuencia. Pero en APEG también puedes escribir una expresión que, cuando se evalúa, **produce el AST de esa secuencia como un valor**, sin parsearlo todavía.

Eso son los meta-operadores. Cada constructor PEG tiene su versión "meta":

|PEG normal|Meta-versión|Qué produce|
|---|---|---|
|`p1 . p2`|`e1 ⊙ e2`|Un valor `VPeg` que representa una secuencia|
|`p1 / p2`|`e1 ⊘ e2`|Un valor `VPeg` que representa una alternativa|
|`!p`|`!̂ e`|Un valor `VPeg` que representa un not-predicate|
|`p*`|`e ⊛`|Un valor `VPeg` que representa una repetición|
|`?e`|`?̂ e`|Un valor `VPeg` que representa un constraint|

Y el más importante, el que crea reglas completas:

```
def e ē::ēⁿ ē::ēᵐ e
```

Esto construye una **regla entera** como valor — nombre, parámetros con tipos, y cuerpo.

**¿Para qué sirve todo esto?** Para que en μSugar puedas escribir:

```
define sfor {
    stmt → "for" ...
}
```

Eso no _parsea_ el for — construye el **AST de la regla `stmt → "for" ...`** como un valor `VGrm`, para después activarla dinámicamente.

---

## Semántica básica (Fig. 10)

### Lit — literales

```
Θ = cualquier entorno
e = 42  (o "hola", o true)
──────────────────────────
v = 42   ← el valor directo
```

Nada sorprendente. Un literal evalúa a su valor directo via la función `L`.

### Op — operadores

```
Θ = ⟨ {"x"/5}, ... ⟩
e = 3 + 4
──────────────────────────
v = 7   ← aplica la función F al operador
```

Evalúa ambos lados y aplica la operación via la función `F`.

### A-ref — leer una variable

```
Θ = ⟨ {"x"/10, "y"/25}, ... ⟩
e = x
──────────────────────────────
v = 10   ← busca x en V_Θ
```

Solo busca el valor en el diccionario del entorno actual. Igual que leer una variable en cualquier lenguaje.

### A-map — acceso a mapa

```
Θ = ⟨ {"sigma"/ {"for"→reglaFor, "sql"→reglaSQL} }, ... ⟩
e = sigma[["for"]]
──────────────────────────────────────────────────────────
v = reglaFor   ← busca la clave "for" en el mapa sigma
```

Evalúa la expresión a un mapa, evalúa la clave a un string, y retorna el valor asociado.

### U-map — actualizar mapa

```
σ  = { "for"→reglaFor, "sql"→reglaSQL }
e  = σ["while"/reglaWhile]
──────────────────────────────────────────
v  = { "for"→reglaFor, "sql"→reglaSQL, "while"→reglaWhile }
     ← nuevo mapa con la entrada añadida
```

No modifica el mapa original — devuelve uno **nuevo** con la actualización.

### L-map — literal de mapa

```
e = { "a"/1, "b"/2 }
──────────────────────
v = { "a"/1, "b"/2 }   ← construye el mapa directamente
```

---

## Extensión de gramáticas (Fig. 11) — lo más importante

Aquí es donde APEG se distingue de PEG puro. Hay **dos operaciones** de extensión, y la diferencia entre ellas importa mucho.

### G-ext — componer gramáticas crudas

```
e  evalúa a v_g  = { "stmt" → reglaStmt_base }
e' evalúa a v'_g = { "stmt" → reglaStmt_for,
                     "for"  → reglaFor }

e ⊲ e' evalúa a:
──────────────────────────────────────────
v_g ⊎ v'_g = {
    "stmt" → reglaStmt_base / reglaStmt_for,   ← ambas se combinan con /
    "for"  → reglaFor                           ← nueva, entra directo
}
```

El operador `⊎` hace la unión. Si las dos gramáticas tienen la misma regla `A → p1` y `A → p2`, la gramática resultante tiene `A → p1 / p2` — prioridad al original. Esta operación **no verifica tipos**, solo pega las reglas.

### L-ext — extender el lenguaje (con type-check)

```
e  evalúa a v_g/Γ   ← un lenguaje (gramática + contexto de tipos)
e' evalúa a v'_g    ← una gramática nueva

e ⊲ e' evalúa a:
──────────────────────────────────────────────────────
1. Se une la gramática:  v_g ⊎ v'_g
2. Se type-checkea:      Γ ⊢ v_g ⊎ v'_g ~> Γ'
3. Resultado:            (v_g ⊎ v'_g) / Γ'  ← nuevo lenguaje verificado
```

La diferencia principal es que el primer argumento evalúa un valor de lenguaje. La gramática resultante se type-checkea en el contexto de tipos del lenguaje.

**¿Por qué dos operaciones distintas?**

||G-ext|L-ext|
|---|---|---|
|Entrada|gramática + gramática|**lenguaje** + gramática|
|Type-check|❌ No|✅ Sí|
|Para qué sirve|Construir gramáticas parcialmente|Activarlas para parsear|

Puedes construir tu gramática por partes con G-ext (barato, sin verificar), y solo cuando la vas a usar como atributo lenguaje en una llamada, la promueves a lenguaje con L-ext (type-check). Eso evita errores cuando buscas definiciones de no-terminales.

**Conexión con μSugar:**

```
-- Esto en el capítulo 2 era magia, ahora tiene sentido:

define sfor {                     ← G-ext: construye VGrm sin verificar
    stmt → "for" ...
}

syntax sfor {                     ← L-ext: lo une al lenguaje base y type-checkea
    for (i := 0; i < 10; ...) {
        print i;
    }
}
```

---

## Construcción de ASTs — las reglas M-*

El resto del capítulo define cómo cada meta-operador produce su valor AST. La notación `'[...]` significa "esto es un AST".

### Reglas unarias (Fig. 12)

```
── M-Empty ──
e = λ̂
────────────
v = '[λ]   ← AST de la expresión vacía

── M-Term ──
e = â       (donde a es un terminal)
────────────
v = '[a]   ← AST del terminal

── M-Not ──
e evalúa a v_p  (un VPeg)
────────────────────────────────────
!̂e evalúa a '[!v_p]   ← AST del not-predicate

── M-Star ──
e evalúa a v_p
──────────────────────────
e⊛ evalúa a '[v_p*]   ← AST de la repetición

── M-Cons ──
e evalúa a v_e  (un VExp)
─────────────────────────────────
?̂e evalúa a '[?v_e]   ← AST del constraint
```

### Reglas binarias (Fig. 13)

```
── M-Seq ──
e evalúa a v_p, e' evalúa a v'_p
──────────────────────────────────────────
e ⊙ e' evalúa a '[v_p . v'_p]   ← AST de secuencia

── M-Choice ──
e evalúa a v_p, e' evalúa a v'_p
──────────────────────────────────────────
e ⊘ e' evalúa a '[v_p / v'_p]   ← AST de alternativa

── M-Bind ──
e evalúa a v_e, e' evalúa a v_p
──────────────────────────────────────────
e =̂ e' evalúa a '[v_e = v_p]   ← AST del bind

── M-Update ──
e evalúa a v_e, e' evalúa a v'_e
──────────────────────────────────────────
e ←̂ e' evalúa a '[v_e ← v'_e]   ← AST del update
```

### M-Call y M-Def (Fig. 14) — los más importantes

**M-Call** construye el AST de una llamada a no-terminal:

```
e evalúa a v_A         (nombre del no-terminal)
ē' evalúa a ē_e        (parámetros heredados)
ē'' evalúa a ē_e       (atributos sintetizados)
──────────────────────────────────────────────
⟨e ē' ē''⟩ evalúa a '[v_A v̄_e v̄_e]
```

**M-Def** construye una regla entera como valor singleton de gramática:

```
e  evalúa a v_A        (nombre de la regla)
ē₁ :: ē₂ evalúan a     (parámetros con sus tipos)
ē₃ :: ē₄ evalúan a     (retornos con sus tipos)
e' evalúa a v_p        (cuerpo de la regla — un VPeg)
──────────────────────────────────────────────────────────
def e ē₁::ē₂ ē₃::ē₄ e'  evalúa a
    '[v_A v̄_g :: v̄_τⁿ v̄_τ'ᵐ → v_p]   ← VGrm con una sola regla
```

**Ejemplo concreto en μSugar:**

```
-- Esto en μSugar:
define sfor {
    stmt → "for" '(' attr ';' expr ';' attr ')' block;
}

-- Internamente usa M-Def para construir:
VGrm {
    "stmt" → '[  lit "for" . lit "(" . call "attr" ... ]
}
-- Un VGrm con una sola regla, listo para ser combinado con L-ext
```

---

## 📊 Resumen del capítulo 3

|Concepto|Qué hace|
|---|---|
|`(Θ, e) ~> v`|Evalúa expresión `e` sin consumir texto|
|`VGrm`|Gramática cruda — colección de reglas sin verificar|
|`VLan`|Lenguaje — gramática type-checkeada + contexto de tipos|
|`G-ext (⊲)`|Une gramáticas crudas, sin type-check|
|`L-ext (⊲)`|Une gramáticas y type-checkea, produce un nuevo lenguaje|
|Meta-operadores `mp`|Construyen ASTs de PEG como valores `VPeg`|
|`M-Def`|Crea una regla nueva completa como `VGrm` singleton|

**La idea central del capítulo:**

APEG trata las gramáticas como **valores de primera clase**. Igual que en Haskell puedes pasar funciones como parámetros, en APEG puedes construir reglas, combinarlas, pasarlas como parámetros a no-terminales, y activarlas dinámicamente. Eso es lo que hace posible la extensión de sintaxis en tiempo de parseo.

# 📖 Capítulo 4 — Implementación en Haskell

## ¿De qué va este capítulo?

En los caps 2 y 3 todo era matemática formal — reglas de semántica, notaciones con flechas, entornos Θ. El cap 4 traduce todo eso a **código Haskell real**.

La idea central es que APEG se implementa como un **DSL embebido** en Haskell. Eso significa que no hay archivos de gramática externos ni un parser de gramáticas — escribes la gramática directamente en Haskell usando funciones y tipos algebraicos, y un intérprete la ejecuta.

Analogía con tu lab de compiladores en C++:

```
Tu lab:
input.txt → scanner.cpp → tokens → parser.cpp → AST → visitor.cpp → output

APEGHaskell:
gramática hardcodeada en Haskell → type-checker → intérprete + input → éxito/falla
```

La diferencia clave: en tu lab las reglas del parser son fijas. En APEGHaskell puedes construir reglas nuevas en tiempo de ejecución, combinarlas con la gramática base, y parsear con ellas.

---

## Las tres capas de la implementación

```
Capa 1 — Tipos de datos     →  representan los valores del cap 3
Capa 2 — Combinadores       →  implementan las reglas del cap 2
Capa 3 — DSL                →  interfaz cómoda para construir gramáticas
```

---

## Capa 1 — Tipos de datos

### Value — los valores semánticos (Fig. 15)

Recuerda del cap 3 que los valores podían ser strings, enteros, gramáticas, ASTs, etc. Esto se traduce directamente a un tipo algebraico en Haskell:

```haskell
data Value = VStr String          -- string
           | VInt Int             -- entero
           | VBool Bool           -- booleano
           | VMap (M.Map String Value)  -- mapa/diccionario
           | VLan ApegGrm TyEnv   -- lenguaje (gramática type-checkeada)
           | VGrm ApegGrm         -- gramática cruda (sin type-check)
           | VPeg APeg            -- AST de una expresión PEG
           | VExp Expr            -- AST de una expresión
           | VType Type           -- AST de un tipo
           | Undefined            -- valor indefinido (el ⊥ del cap 2)
           deriving Show
```

Cada constructor es exactamente uno de los valores semánticos del cap 3. `Undefined` es el `⊥` — cuando algo falla.

La distinción importante que ya vimos:

- `VGrm` → gramática cruda, solo pegaste reglas con G-ext
- `VLan` → gramática type-checkeada, lista para usarse como atributo lenguaje

### PureState — el entorno Θ (Fig. 16)

El entorno Θ del cap 2 era `⟨V, Γ⟩`. Aquí se expande con todo lo que el parser necesita cargar:

```haskell
newtype PureState = PureState ( VEnv      -- V: variables y sus valores
                              , TyEnv     -- Γ: variables y sus tipos
                              , MybStr    -- prefijo consumido hasta ahora
                              , Input     -- texto de entrada restante
                              , Result    -- resultado del último statement
                              )
           deriving Show
```

|Campo|Qué es|Equivalente cap 2|
|---|---|---|
|`VEnv`|diccionario variable → valor|`V` de Θ|
|`TyEnv`|diccionario variable → tipo|`Γ` de Θ|
|`MybStr`|texto ya consumido|el `z` de la notación|
|`Input`|texto que falta por leer|el `w` restante|
|`Result`|éxito o falla del último paso|el `⊥` o éxito|

Este `PureState` se usa como el estado en una **State Monad**, lo que permite que todas las funciones del parser lean y modifiquen el estado sin pasarlo manualmente todo el tiempo.

---

## Capa 2 — La State Monad y los combinadores

### La monad (Fig. 17)

```haskell
type APegSt = State PureState
```

Con esto, cualquier función del parser tiene tipo `APegSt ()` — una acción que lee/modifica el `PureState` y no devuelve nada útil (solo el efecto de parsear).

Las funciones base son:

```haskell
pfail :: APegSt ()
pfail = modify (setResult (rErr []))   -- marca el estado como fallido

done :: APegSt ()
done = modify assureOkStatus           -- marca el estado como exitoso

isOk :: APegSt Bool
isOk = get >>= return . stIsOk        -- ¿el estado actual es exitoso?

patternMatch :: String -> APegSt ()
patternMatch s = modify (match s)     -- intenta consumir el string s del input

onSuccess :: APegSt a -> APegSt a -> APegSt a
onSuccess suc fai = isOk >>= f
    where f b = if b then suc else fai  -- ejecuta suc o fai según el estado
```

Estas son las piezas más pequeñas. Todo lo demás se construye sobre ellas.

### kleene — la regla Star (Fig. 18)

```haskell
kleene :: APegSt () -> APegSt ()
kleene p =
    do s <- get          -- guarda el estado actual
       p                 -- intenta aplicar p
       onSuccess (kleene p) (put s >> done)  -- si éxito repite, si falla resetea
```

Traducción directa de la regla **Star** del cap 2:

- Aplica `p` una y otra vez
- Cuando `p` falla, resetea el estado al anterior y termina con éxito
- Nunca devuelve falla — cero repeticiones es válido

### sequential — la regla Seq (Fig. 18)

```haskell
sequential :: APegSt () -> APegSt () -> APegSt ()
sequential p q
    = do st <- get       -- guarda estado antes de p
         p               -- aplica p
         onSuccess q (put st >> pfail)  -- si p éxito aplica q, si no rollback
```

Traducción de la regla **Seq**:

- Si `p` falla → rollback al estado guardado, falla
- Si `p` éxito → aplica `q`
- Si `q` falla → falla (el rollback de `p` ya no aplica, `q` maneja su propio estado)

### alternate — la regla Choice (Fig. 18)

```haskell
alternate :: APegSt () -> APegSt () -> APegSt ()
alternate l r
    = do s <- get        -- guarda estado antes de intentar l
         l               -- intenta la rama izquierda
         onSuccess (return ()) (put s >> r)  -- si l éxito listo, si no resetea e intenta r
```

Traducción de la regla **Choice**:

- Intenta `l` primero
- Si `l` éxito → termina, `r` ni se mira
- Si `l` falla → resetea el estado a como estaba y prueba `r`

### notPeg — la regla Not (Fig. 19)

```haskell
notPeg :: APegSt () -> APegSt ()
notPeg p
    = do st <- get
         p
         st' <- get
         let st'' = ((setInput (remInp st')).(setPrefix (getPrefix st))) st'
             in onSuccess (put st'' >> pfail) (put st'' >> done)
```

Traducción de la regla **Not**:

- Si `p` éxito → `!p` falla, resetea input y prefijo
- Si `p` falla → `!p` éxito, resetea input y prefijo
- **Importante:** los cambios al entorno de variables sí se conservan (igual que en el cap 2)

### bindApeg y update (Fig. 20)

```haskell
bindApeg :: Var -> APegSt () -> APegSt ()
bindApeg s p = do prfx <- getStr   -- guarda prefijo actual
                  resetStr         -- resetea el prefijo a vacío
                  p                -- aplica p
                  res <- getStr    -- lee lo que p consumió
                  modify (prependPrefix prfx)
                  varSet s (vstr $ fromMybStr res)  -- guarda en variable s
```

Traducción de **Bind** `ϑ = p`:

- Resetea el prefijo a vacío
- Aplica `p`
- Lo que `p` consumió queda en el prefijo — lo guarda en la variable `s`

```haskell
update :: Var -> APegSt Value -> APegSt ()
update v p = p >>= (varSet v)
```

Traducción de **Update** `ϑ ← e`:

- Evalúa la acción `p` (que devuelve un `Value`)
- Guarda ese valor en la variable `v`

---

## Capa 3 — El DSL para construir ASTs

En vez de construir el árbol a mano así:

```haskell
Seq (Lit "for") (Seq (Lit "(") (NT "expr" [] []))
```

El DSL te da funciones con nombres legibles:

```haskell
-- Construcción de expresiones de parsing (Fig. 23)
lit    :: String -> APeg           -- terminal
lam    :: APeg                     -- expresión vacía λ
(.=.)  :: String -> Expr -> APeg   -- bind: ϑ = p
(.<.)  :: String -> Expr -> APeg   -- update: ϑ ← e
(./.)  :: APeg -> APeg -> APeg     -- alternativa: p / q
(.:.)  :: APeg -> APeg -> APeg     -- secuencia: p . q
seqs   :: [APeg] -> APeg           -- secuencia de una lista
alts   :: [APeg] -> APeg           -- alternativa de una lista
star   :: APeg -> APeg             -- repetición: p*
star1  :: APeg -> APeg             -- repetición positiva: p+
call   :: String -> [Expr] -> [Var] -> APeg  -- llamada a no-terminal
rule   :: String -> [(Type,Var)] -> [(Type,Expr)] -> APeg -> ApegRule  -- regla completa
(.::)  :: a -> Type -> (Type, a)   -- anotación de tipo
npred  :: APeg -> APeg             -- not-predicate: !p
(|?|)  :: Expr -> APeg -> APeg     -- constraint: ?e
```

### Ejemplo concreto — lenguaje dependiente de datos (Fig. 25)

El lenguaje: una palabra que empieza con número `n` seguido de exactamente `n` letras entre corchetes. Ejemplo válido: `3[abc]`.

```haskell
ddl :: ApegGrm
ddl = [ruleStart, ruleDigit]

ruleStart :: ApegRule
ruleStart
    = rule "start"
           ["g" .:: tLang]    -- parámetro: atributo lenguaje
           []                  -- sin retorno
           (seqs [ "n" .<. int 0,                    -- n = 0
                   call "digit" [v "g"] ["n"],        -- lee el dígito, guarda en n
                   lit "[",
                   star ( seqs [ (int 0) |<| (v "n") |?| lowLetter,  -- ¿n > 0? lee letra
                                 "n" .<. ((v "n") |-| (int 1)) ]),    -- n = n - 1
                   ((int 0) |=| (v "n")) |?| lit "]"  -- confirma n == 0, cierra
                 ])

ruleDigit :: ApegRule
ruleDigit
    = rule "digit"
           ["g" .:: tLang]
           ["s" .:: tInt]      -- retorna el dígito como entero
           (alts [ lit "1" .:. "s" .<. int 1,
                   lit "2" .:. "s" .<. int 2,
                   lit "3" .:. "s" .<. int 3,
                   -- ... hasta 9
                   lit "9" .:. "s" .<. int 9 ])
```

**Input `"3[abc]"` → output:**

```
Éxito ✓
n empieza en 0
digit lee "3" → n = 3
lee "a" → n = 2
lee "b" → n = 1
lee "c" → n = 0
constraint (0 == 0) → éxito
lee "]" → éxito
```

**Input `"3[ab]"` → output:**

```
Falla ✗
n empieza en 0
digit lee "3" → n = 3
lee "a" → n = 2
lee "b" → n = 1
constraint (0 == 1) → falla ✗
```

---

## El flujo completo de uso

```
1. Escribes tu gramática con el DSL
            ↓
2. Se type-checkea el AST (verifica atributos)
            ↓
3. Se pasa al intérprete junto con el input string
            ↓
4. El intérprete corre los combinadores sobre el PureState
            ↓
5. Resultado: éxito o falla + árbol de derivación
```

### Limitaciones que mencionan los autores

- El **well-formedness check** no está implementado — algunos programas que deberían rechazarse por causar loops infinitos pasan el type-checker igual
- No hay sintaxis concreta — la gramática siempre se escribe hardcodeada con el DSL, no puedes pasarla como archivo de texto
- El árbol de derivación se construye pero la semántica de lenguajes auto-extensibles aún no está explorada

---

## 📊 Resumen del capítulo 4

|Capa|Qué hace|Equivalente cap 2/3|
|---|---|---|
|`Value`|Tipos de datos para valores semánticos|Los `v` del cap 3|
|`PureState`|El estado completo del parser|El entorno Θ del cap 2|
|`APegSt`|State Monad sobre PureState|El `(Θ, p) ⇝w z ⊳ Θ'`|
|`kleene`|Repetición|Regla Star|
|`sequential`|Secuencia con rollback|Regla Seq|
|`alternate`|Elección priorizada|Regla Choice|
|`notPeg`|Lookahead negativo|Regla Not|
|`bindApeg`|Captura de texto|Regla Bind|
|`update`|Asignación de valor|Regla Update|
|DSL (`lit`, `call`, `rule`...)|Construir ASTs cómodamente|Los meta-operadores del cap 3|

# 📖 Capítulo 5 — El Diseño de μSugar

## ¿De qué va este capítulo?

Los caps 2, 3 y 4 te dieron las **herramientas**: la semántica formal, los meta-operadores y la implementación en Haskell. El cap 5 las **usa para algo real**: construir un parser completo para μSugar, el lenguaje extensible de juguete que apareció al inicio del paper.

El capítulo tiene tres partes:

```
5.1 → Cómo se implementa μSugar usando el DSL de APEG (las reglas del parser)
5.2 → Ejemplos reales de extensiones (pairs, foreach, SQL) y cómo combinarlas
5.3 → Discusión honesta: qué cosas son difíciles o imposibles y por qué
```

> **Idea clave del capítulo:** El propio μSugar (incluyendo su mecanismo de "define" y "syntax") está escrito como una gramática APEG. O sea, APEG es lo bastante potente como para describir un lenguaje que se extiende a sí mismo.

---

## 5.1 — Implementando μSugar en APEG

Un programa μSugar es: **declaraciones de sintaxis** (`define`) seguidas de **bloques de sentencias** (que pueden activar extensiones con `syntax`). Cada regla del parser de μSugar es una función del DSL de Haskell del cap 4.

El truco central de toda la implementación es un **mapa `sigma`** que funciona como catálogo de extensiones:

```
sigma = {
    "0"     → gramática vacía (Epsilon),   ← entrada inicial obligatoria
    "sfor"  → gramática del for,
    "pair"  → gramática de pares,
    ...
}
```

Cada `define` mete una entrada nueva en `sigma`; cada `syntax` saca una entrada de `sigma` y la fusiona con la gramática base.

### `ruleProg` (Fig. 26) — la regla raíz

```
1. Inicializa sigma = { "0" → Epsilon }   ← necesario para que sigma tenga un tipo
2. star  (newSyn)     ← reconoce 0+ definiciones "define", cada una actualiza sigma
3. star1 (extBlock / block)  ← luego 1+ bloques (extendidos o normales)
```

> **¿Por qué la entrada `"0" → Epsilon`?** Porque actualmente no hay forma de crear un atributo *sin inicializar*. Necesitan que `sigma` ya tenga un tipo `(mapa de gramáticas)` antes de empezar a llenarlo, así que le ponen una entrada dummy con la gramática vacía.

### `ruleNewSyn` (Fig. 27) — procesar un `define`

Reconoce algo como `define <nombre> { reglas... }` y devuelve el `sigma` actualizado.

```
define sfor {              ← reconoce la palabra "define" y el nombre n = "sfor"
    stmt → ...             ← star de "rule": acumula cada regla en el atributo lan
    nfor → ...
}
─────────────────────────────────────────────
lan empieza en Epsilon, cada regla se compone con <+:
al final: mapins sigma["sfor" / lan]   ← inserta la gramática nueva en sigma
```

La construcción de la gramática **empieza vacía (`Epsilon`)** y va componiendo regla por regla con el operador `<+:`.

### `ruleExtStmt` (Fig. 28) — procesar un `syntax`

Reconoce los bloques que **usan** las extensiones: `syntax <nombre>, <nombre>... { ... }`.

```
syntax sfor {                  ← reconoce "syntax" y el/los nombre(s) n
    for (...) { ... }          ← busca "sfor" en sigma → obtiene su gramática
}
─────────────────────────────────────────────
newSyn = unión de todas las gramáticas nombradas (<+:)
call "block" [g <+: newSyn]    ← parsea el bloque con base + extensiones
```

> **⚠️ El orden de composición importa — `<+:` NO es conmutativo.** Como la semántica de APEG agrega las extensiones **al final** de las reglas de producción, y la elección de PEG es **priorizada y determinista** (cap 2, regla Choice), `g <+: newSyn` no es lo mismo que `newSyn <+: g`. Las reglas base mantienen prioridad y las extensiones se intentan después.

### `ruleRule` (Fig. 29) y `rulePattern` (Fig. 30) — el "meta-parser"

Estas dos reglas son las que **leen reglas gramaticales escritas como texto** y las convierten en valores `VGrm`:

| Regla | Qué hace |
|---|---|
| `ruleRule` | Reconoce `nt -> pattern ;` y lo arma con el operador `MkRule`. El nombre sale del no-terminal `nt` (un `rid` = letra seguida de letras/dígitos). |
| `rulePattern` | Construye una **alternativa** PEG: reconoce un `pseq`, y luego repite `/ pseq` para las opciones, usando `MetaPeg` para volverlo un AST. |

**Restricciones de las reglas extendidas:**
- Sus parámetros se fijan a ser **solo el atributo lenguaje** `g`.
- **Nunca retornan** atributos sintetizados.

Esto simplifica los ejemplos (no hay que manejar atributos en las extensiones de μSugar).

**Conexión con el cap 3:** Aquí se ve en acción el `M-Def` — `MkRule` es la versión Haskell del meta-operador que construye una regla completa (`def`) como `VGrm` singleton.

---

## 5.2 — Definiendo extensiones de μSugar

Tres ejemplos en complejidad creciente, más uno de combinación.

### 5.2.1 — Pares `(e1, e2)` (Fig. 31)

```
define pair {
    factor -> "(" expr "," expr ")";   ← extiende el no-terminal factor
}
syntax pair {
    x := (2,1) + (1,2);
}
```

> **Decisión clave:** lo agregan al nivel de **`factor`** (lo más bajo de la jerarquía de expresiones). Como un par es un valor de primera clase, debe poder usarse en cualquier parte de una expresión — dentro de sumas, etc. Si lo hubieran puesto en otro no-terminal más alto, no funcionaría como esperaban. La Fig. 32 muestra el árbol de parseo resultante.

### 5.2.2 — `foreach` (Fig. 33)

```
define foreach {
    stmt -> whites "foreach(" whites identifier whites ":" whites expr whites ")" block ;
}
syntax foreach {
    x := 10;
    foreach( i : x ){ y := i + 10; }
}
```

Se extiende a nivel de **`stmt`** (sentencia). Funciona porque **ninguna alternativa de `stmt` empieza con la palabra `foreach`**, así que no hay conflicto.

> **Advertencia de los autores:** el programador que escribe extensiones **debe conocer la especificación de μSugar** para no chocar con reglas existentes. La extensibilidad no es automática ni a prueba de errores.

### 5.2.3 — Subconjunto de SQL (Fig. 34)

El más complejo: mete un mini-lenguaje de consultas dentro de μSugar.

```
define query {
    stmt   -> ... "<--?" ... SQLexp ... ;   ← nuevo operador de asignación
    SQLexp -> "SELECT" fieldList "FROM" ... ("WHERE" condition)? ;
    ...
}
syntax query {
    x <--?  SELECT * FROM table;
}
```

Trucos de diseño para evitar conflictos:
- Los comandos se escriben **TODO EN MAYÚSCULAS** (`SELECT`, `FROM`, `WHERE`) para distinguirlos de los identificadores.
- Usa un operador nuevo `<--?` para asignar el resultado a una variable (en vez de reusar `:=`).
- Reutiliza el lexema de los identificadores como nombres de campos → sintaxis más limpia.

### 5.2.4 — Combinando extensiones (Fig. 35)

El poder real: activar **varias extensiones a la vez** en el mismo bloque.

```
syntax query, foreach {
    x <--?  SELECT * FROM table;
    foreach(z : x){ print(z); }
}
```

Como `ruleExtStmt` fusiona con `<+:` **todas** las gramáticas nombradas, puedes combinar `query` + `foreach` y usar ambas sintaxis simultáneamente.

---

## 5.3 — Discusión: lo difícil y lo imposible

Diseñar un lenguaje extensible es **más complicado de lo que parece**. El diseñador decide qué partes se pueden extender, y además hereda las "rarezas" de PEG (determinismo + backtracking local).

### Problema 1 — Palabras reservadas vs identificadores (Fig. 36)

Por el determinismo de PEG, distinguir una palabra reservada de un identificador **no es trivial**. Si un identificador es "letras/dígitos que empiezan con minúscula":

```
while := 10;    ← ¡PEG acepta "while" como identificador! ✗ (no debería)
```

**Dos soluciones:**
1. Cambiar la **prioridad** de las reglas para que la asignación se intente al final.
2. Excluir reservadas con **predicados negativos** (regla Not del cap 2):

```
!( ('print' | 'while') !(letter-or-digit) ) (identifier) := exp ;
```

### Problema 2 — Precedencia de operadores (Fig. 37)

Agregar `*` y `/` parece trivial pero **no lo es**. Quieren que tengan más precedencia que `+` y `-`, pero **no pueden extender `cexpr`** porque la operación kernel hace que `cexpr` acepte cualquier expresión que empiece con un `factor` → se rompe la jerarquía de precedencia.

### Problema 3 — Llamadas a función (Figs. 38 y 39)

Intentar meter `fat(10)` extendiendo `factor`:

```
define func {
    fator -> whites identifier whites params whites ";";   ← empieza con identifier
}
```

Como la producción `var` (que también sale de `factor` y **también empieza con un identificador**) tiene **prioridad**, la extensión queda **inútil**: PEG siempre elige `var` primero. La Fig. 39(a) muestra el parser **rechazando** la entrada (`REJECTED!`).

> **Conclusión importante:** Ninguno de estos problemas es **inherente a APEG**. Se pueden resolver **refactorizando la sintaxis de μSugar** — por ejemplo, agregando no-terminales en los lugares donde se esperan extensiones de mayor prioridad. La lección es de **diseño de lenguajes**, no una limitación del modelo formal.

---

## 📊 Resumen del capítulo 5

| Tema | Idea central |
|---|---|
| `sigma` | Mapa catálogo: `define` lo llena, `syntax` lo consume |
| `ruleProg` | Regla raíz: define extensiones → ejecuta bloques |
| `ruleNewSyn` | Procesa `define`, arma un `VGrm` y lo guarda en `sigma` |
| `ruleExtStmt` | Procesa `syntax`, fusiona extensiones con `<+:` y parsea el bloque |
| `ruleRule` / `rulePattern` | Meta-parser: leen reglas escritas como texto y las vuelven `VGrm` |
| Orden de `<+:` | **No conmutativo** — la base mantiene prioridad (PEG determinista) |
| Extensiones | pairs (`factor`), foreach (`stmt`), SQL (`stmt`) — combinables a la vez |
| Limitaciones | Reservadas vs identificadores, precedencia, llamadas a función |
| Moraleja | Los conflictos son de **diseño de la sintaxis**, no fallas de APEG |

**La idea central del capítulo:**

μSugar demuestra que APEG **funciona en la práctica**: un lenguaje real que se extiende a sí mismo, escrito enteramente con el DSL de Haskell. Pero también muestra que la extensibilidad **no es gratis** — el diseñador debe pensar con cuidado qué no-terminales expone, porque el determinismo de PEG hace que el **orden y la prioridad de las reglas** determinen si una extensión funciona o se vuelve inútil.

# 📖 Capítulo 6 — Trabajos Relacionados

## ¿De qué va este capítulo?

Es el típico capítulo de "qué hicieron otros antes". Lo ubican en **dos grandes familias** que tocan el mismo problema desde ángulos distintos: el **parsing** (cómo analizar texto) y el **meta-programming** (cómo extender un lenguaje desde adentro).

---

## Familia 1 — Parsing

El parsing es uno de los problemas más estudiados en computación y sigue activo. Algunos trabajos que mencionan:

| Trabajo | Aporte | Limitación frente a este paper |
|---|---|---|
| Parsing por memoización de CFG | Algoritmo eficiente, 3–5× más rápido que el estado del arte en código Java real | No aborda la **extensibilidad** del lenguaje |
| Zippers + LL(1) | Parser con referencias funcionales (zippers), implementado en Scala | Gramáticas **fijas**, no se extienden |
| Intérprete PEG verificado en PVS | Usa la noción de *well-formed grammar*; prueba solidez y completitud con trazas | No modela agregar reglas al vuelo |
| Parsing por derivadas (Brzozowski + zipper de Huet) | Suspende y reanuda el recorrido sin re-parsear; implementado en OCaml | Igual: no toca extensibilidad |

> **El punto en común:** todos estos son algoritmos de parsing **interesantes, verificados y eficientes**, pero **ninguno aborda la extensibilidad del lenguaje** — que es justo el hueco que llena este paper.

---

## Familia 2 — Meta-programación

La idea de extender un lenguaje desde adentro viene de **Lisp** y sus dialectos modernos (recuerda el cap 1). Aquí la meta-programación basada en macros es la tradición.

| Sistema | Qué hace |
|---|---|
| **Racket** | Dialecto moderno de Lisp; favorece la *programación orientada a lenguajes* (escribir mini-DSLs y combinarlos para construir software) |
| **Template Haskell** | Extensión de Haskell para meta-programación en tiempo de compilación: genera código y expansiones tipo macro |
| **Template Haskell + quasi-quotation** | Añade sintaxis concreta para *quasi-quotes*, clave en frameworks web modernos de Haskell |
| **Stratego/XT** | Lenguaje de transformación de programas por reglas de reescritura; usa sintaxis concreta de objeto. Hoy parte del *language workbench* Spoofax |
| Survey de Lilis & Savidis | Taxonomía de lenguajes de meta-programación, clasificados por modelo, fase de evaluación, ubicación del meta-programa y relación meta/objeto |

> **Dónde encaja APEG:** se mueve en este mundo de "lenguajes que se extienden a sí mismos", pero su aporte es **formalizar la extensión a nivel de la gramática del parser** (no de macros sobre el AST ya parseado), algo que las herramientas de meta-programación no modelan formalmente.

---

## 📊 Resumen del capítulo 6

| Familia | Qué cubren | Qué les falta |
|---|---|---|
| **Parsing** (memoización, zippers, derivadas, PEG verificado) | Algoritmos rápidos y verificados | No modelan **extensibilidad** |
| **Meta-programación** (Racket, Template Haskell, Stratego/XT) | Extender lenguajes con macros/reescritura | No **formalizan** la extensión de la gramática al parsear |

APEG se sitúa en la intersección: toma la **base de parsing (PEG)** y le añade la **extensibilidad formalizada** que a los demás les falta.

# 📖 Capítulo 7 — Conclusiones

## El cierre del paper

APEG es un **modelo formal** para describir modificaciones de gramática "al vuelo". El problema que resolvieron: las formalizaciones **previas de APEG estaban incompletas** — tenían un hueco crítico, **no modelaban el mecanismo de construir/agregar reglas nuevas**, aunque eso es justo el corazón de APEG.

### Lo que aportó este trabajo

```
1. Completó la formalización de APEG
   → ahora sí se modela cómo se construyen las reglas nuevas
   → y cómo interactúan con el sistema de tipos al insertarse

2. Implementó esa semántica monádica en Haskell
   → las gramáticas APEG son cómputos monádicos (State Monad)

3. Implementó μSugar completo con esa librería
   → con ejemplos reales: pairs, foreach, SQL
   → y discutió los problemas de diseñar lenguajes extensibles
```

### Limitaciones que reconocen (lo pendiente)

| Limitación | Qué significa |
|---|---|
| **Sin well-formedness check** | No verifican que la gramática esté bien formada → programas que causan **loops infinitos** pasan el type-checker igual (ya lo vimos en cap 4) |
| **Sin sintaxis concreta** | La gramática se escribe **hardcodeada con el DSL** de Haskell; no puedes pasarla como archivo de texto, lo que puede ser engorroso |

### Trabajo futuro

- Implementar el **chequeo de buena formación** (well-formedness).
- Crear una **interfaz más amigable** para escribir gramáticas APEG (idealmente una sintaxis concreta).
- Más ejemplos de lenguajes extensibles.
- **Experimentos de eficiencia** del prototipo.

---

## 📊 Resumen del capítulo 7

| Pregunta | Respuesta |
|---|---|
| ¿Qué problema resolvieron? | El hueco en la formalización previa: **cómo se agregan reglas nuevas** |
| ¿Cómo? | Formalización completa + implementación monádica en Haskell + parser de μSugar |
| ¿Qué quedó pendiente? | Well-formedness check, sintaxis concreta, más ejemplos, medir eficiencia |

**La idea final:**

El paper **cierra el círculo** del cap 1: prometió un modelo formal y completo para lenguajes extensibles, y lo entregó — pero deja claro que pasar de un **prototipo formal** a una **herramienta práctica y robusta** todavía requiere trabajo (sobre todo el chequeo de buena formación y una sintaxis usable).
