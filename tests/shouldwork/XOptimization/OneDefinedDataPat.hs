module OneDefinedDataPat where

import Clash.Prelude
import Clash.Driver.Types
import Clash.Netlist.Types

import Test.Tasty.Clash
import Test.Tasty.Clash.NetlistTest

topEntity :: Maybe (Unsigned 8) -> Unsigned 8
topEntity m = case m of
    Nothing -> errorX "Nothing: Expected Just"
    Just x  -> x

assertNoMux :: Component -> IO ()
assertNoMux c =
  case go 0 $ declarations c of
    0 -> return ()
    n -> error $ "Expected 0 multiplexers, found " <> show n
 where
  go acc []                    = acc
  go acc (CondAssignment{}:ds) = go (acc + 1) ds
  go acc (_:ds)                = go acc ds

testPath :: FilePath
testPath = "tests/shouldwork/XOptimization/OneDefinedDataPat.hs"

getComponent :: (a, b, c, d) -> d
getComponent (_, _, _, x) = x

enableXOpt :: ClashOpts -> ClashOpts
enableXOpt c = c { opt_aggressiveXOpt = True }

mainVHDL :: IO ()
mainVHDL = do
  netlist <- runToNetlistStage SVHDL enableXOpt testPath
  mapM_ (assertNoMux . getComponent) netlist

mainVerilog :: IO ()
mainVerilog = do
  netlist <- runToNetlistStage SVerilog enableXOpt testPath
  mapM_ (assertNoMux . getComponent) netlist

mainSystemVerilog :: IO ()
mainSystemVerilog = do
  netlist <- runToNetlistStage SSystemVerilog enableXOpt testPath
  mapM_ (assertNoMux . getComponent) netlist

