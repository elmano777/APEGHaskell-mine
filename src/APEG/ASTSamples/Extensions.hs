module APEG.ASTSamples.Extensions where

import APEG.AbstractSyntax
import APEG.DSL
import APEG.PlayGround
import APEG.ASTSamples.MicroSugar (microSugar, semic)

-- ============================================================
--  Extensiones de μSugar definidas directamente en Haskell
--
--  Cada regla nueva tiene el nombre "stmt" y la MISMA firma
--  (heredado: g :: tLang, sintetizado: []) que la regla stmt
--  original de MicroSugar. Por eso 'joinRules' las fusiona como
--  una alternativa (Alt) de la regla stmt existente.
-- ============================================================

-- | repeat { ... } until ( cexpr ) ;   -- bucle do-while
--
-- Ejecuta el bloque y luego evalúa la condición. Usamos literales
-- separados ("until", "(") con 'whts' en medio para tolerar espacios
-- entre la palabra clave y el paréntesis.
ruleRepeatUntil :: ApegRule
ruleRepeatUntil = rule "stmt"
                       ["g" .:: tLang]
                       []
                       (seqs [ whts, lit "repeat",
                               call "block" [g] [],
                               whts, lit "until", whts, lit "(", whts,
                               call "cexpr" [g] [], whts, lit ")",
                               whts, semic ])

-- | unless ( cexpr ) { ... }           -- if negado (azúcar sintáctico)
--
-- Mismo patrón que el 'if' de MicroSugar, solo cambia la palabra clave.
ruleUnless :: ApegRule
ruleUnless = rule "stmt"
                  ["g" .:: tLang]
                  []
                  (seqs [ whts, lit "unless", whts, lit "(", whts,
                          call "cexpr" [g] [], whts, lit ")",
                          call "block" [g] [] ])

-- | Gramática base μSugar extendida con las dos construcciones nuevas.
--   'joinRules' agrega cada regla como una alternativa de "stmt".
microSugarExt :: ApegGrm
microSugarExt = joinRules microSugar [ruleRepeatUntil, ruleUnless]

-- ============================================================
--  Runners (reusan PlayGround sobre la gramática extendida)
-- ============================================================

-- | Parsea el archivo e imprime el árbol de derivación + ACCEPTED/REJECTED.
runExt :: FilePath -> IO ()
runExt = runFile (runGrammar microSugarExt [])

-- | Solo informa si el archivo fue aceptado o rechazado.
acceptExt :: FilePath -> IO ()
acceptExt = runFile (runAccept microSugarExt [])

-- | Imprime el contexto de tipos tras ejecutar.
debugExt :: FilePath -> IO ()
debugExt = runFile (debugRun microSugarExt [])
