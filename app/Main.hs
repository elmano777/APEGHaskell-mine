module Main where

-- CLI del intérprete APEG/μSugar.
--
-- Uso:
--   APEGLitleToy-exe <archivo>          -- usa la gramática extendida (microSugarExt)
--   APEGLitleToy-exe --base <archivo>   -- usa solo la gramática base (microSugar)
--
-- Imprime un formato simple y estable, pensado para que la extensión de
-- VS Code lo lea sin ambigüedad (una línea por dato):
--
--   STATUS ACCEPTED            STATUS REJECTED
--   TREE                       OFFSET <n>            <- n = caracteres consumidos antes del fallo
--   <arbol de derivacion...>   ERROR <mensaje>       <- una linea por error
--
-- Todo lo de parsing ya existe en la librería; aquí solo le damos una
-- "puerta de entrada" por línea de comandos.

import System.Environment (getArgs)
import System.Exit (exitFailure)
import Control.Monad.State.Lazy (runState)

import APEG.AbstractSyntax (ApegGrm)
import APEG.Interpreter.APEGInterp (interpGrammar)
import APEG.Interpreter.State (zeroSt, getResult, remInp)
import APEG.Interpreter.DT (pprintDT)
import APEG.ASTSamples.MicroSugar (microSugar)
import APEG.ASTSamples.Extensions (microSugarExt)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [path]           -> runOn microSugarExt path
    ["--base", path] -> runOn microSugar    path
    _                -> do
      putStrLn "uso: APEGLitleToy-exe [--base] <archivo>"
      exitFailure

-- | Corre una gramática sobre el contenido de un archivo e imprime el
-- resultado en el formato que consume la extensión.
runOn :: ApegGrm -> FilePath -> IO ()
runOn g path = do
  src <- readFile path
  -- Misma invocación que usan los runners de PlayGround: corre el
  -- intérprete (sin atributos heredados extra: []) sobre el estado inicial.
  let (_, ps) = runState (interpGrammar [] g) (zeroSt g src)
  case getResult ps of
    Right (dt:_) -> do
      putStrLn "STATUS ACCEPTED"
      putStrLn "TREE"
      putStr (pprintDT dt)
    Right [] ->
      putStrLn "STATUS ACCEPTED"
    Left errs -> do
      putStrLn "STATUS REJECTED"
      -- El input restante dice DÓNDE se atascó el parser. La diferencia
      -- entre el largo total y el restante = posición (offset) del fallo.
      let offset = length src - length (remInp ps)
      putStrLn ("OFFSET " ++ show offset)
      mapM_ (\e -> putStrLn ("ERROR " ++ oneLine e)) errs
  where
    -- Aplana saltos de línea para que cada error quepa en una sola línea.
    oneLine = map (\c -> if c == '\n' then ' ' else c)
