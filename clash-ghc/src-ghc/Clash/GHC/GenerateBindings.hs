{-|
  Copyright   :  (C) 2013-2016, University of Twente,
                          2017, QBayLogic, Google Inc.
  License     :  BSD2 (see the file LICENSE)
  Maintainer  :  Christiaan Baaij <christiaan.baaij@gmail.com>
-}

{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns      #-}

module Clash.GHC.GenerateBindings
  (generateBindings)
where

import           Control.DeepSeq         (deepseq)
import           Control.Lens            ((%~),(&),view,_1)
import           Control.Monad           (unless)
import qualified Control.Monad.State     as State
import qualified Control.Monad.RWS.Strict as RWS
import           Data.Coerce             (coerce)
import           Data.Either             (partitionEithers, lefts, rights)
import           Data.IntMap.Strict      (IntMap)
import qualified Data.IntMap.Strict      as IMS
import qualified Data.HashMap.Strict     as HashMap
import           Data.List               (isPrefixOf)
import qualified Data.Text               as Text
import qualified Data.Time.Clock         as Clock

import qualified BasicTypes              as GHC
import qualified CoreSyn                 as GHC
import qualified Demand                  as GHC
import qualified DynFlags                as GHC
import qualified IdInfo                  as GHC
import qualified Outputable              as GHC
import qualified Name                    as GHC hiding (varName)
import qualified TyCon                   as GHC
import qualified Type                    as GHC
import qualified TysWiredIn              as GHC
import qualified Util                    as GHC
import qualified Var                     as GHC
import qualified SrcLoc                  as GHC

import           Clash.Annotations.BitRepresentation.Internal (DataRepr')
import           Clash.Annotations.TopEntity (TopEntity)
import           Clash.Annotations.Primitive (HDL, extractPrim)

import           Clash.Core.Subst        (extendGblSubstList, mkSubst, substTm)
import           Clash.Core.Term         (Term (..))
import           Clash.Core.Type         (Type (..), TypeView (..), mkFunTy, splitFunForallTy, tyView)
import           Clash.Core.TyCon        (TyConMap, TyConName, isNewTypeTc)
import           Clash.Core.TysPrim      (tysPrimMap)
import           Clash.Core.Util         (mkLams, mkTyLams)
import           Clash.Core.Var          (Var (..), Id, IdScope (..), setIdScope)
import           Clash.Core.VarEnv
  (InScopeSet, VarEnv, emptyInScopeSet, extendInScopeSet, mkInScopeSet, mkVarEnv, unionVarEnv)
import           Clash.Driver            (compilePrimitive)
import           Clash.Driver.Types      (BindingMap)
import           Clash.GHC.GHC2Core
  (C2C, GHC2CoreState, tyConMap, coreToId, coreToName, coreToTerm,
   makeAllTyCons, qualifiedNameString, emptyGHC2CoreState)
import           Clash.GHC.LoadModules   (ghcLibDir, loadModules)
import           Clash.Netlist.BlackBox.Util (usedArguments)
import           Clash.Primitives.Types
  (Primitive (..), CompiledPrimMap)
import           Clash.Primitives.Util   (generatePrimMap)
import           Clash.Rewrite.Util      (mkInternalVar, mkSelectorCase)
import           Clash.Unique
  (listToUniqMap, lookupUniqMap, mapUniqMap, unionUniqMap, uniqMapToUniqSet)
import           Clash.Util
  ((***),first,traceIf,indexMaybe,reportTimeDiff)

generateBindings
  :: GHC.OverridingBool
  -- ^ Use color
  -> [FilePath]
  -- ^ primitives (blackbox) directories
  -> [FilePath]
  -- ^ import directories (-i flag)
  -> [FilePath]
  -- ^ Package database
  -> HDL
  -- ^ HDL target
  -> String
  -> Maybe GHC.DynFlags
  -> IO ( BindingMap
        , TyConMap
        , IntMap TyConName
        , [( Id
           , Maybe TopEntity -- (maybe) TopEntity annotation
           , Maybe Id        -- (maybe) associated testbench
           )]
        , CompiledPrimMap  -- The primitives found in '.' and 'primDir'
        , [DataRepr']
        )
generateBindings useColor primDirs importDirs dbs hdl modName dflagsM = do
  (  bindings
   , clsOps
   , unlocatable
   , fiEnvs
   , topEntities
   , partitionEithers -> (unresolvedPrims, pFP)
   , customBitRepresentations
   , primGuards ) <- loadModules useColor hdl modName dflagsM importDirs
  primMapR <- generatePrimMap unresolvedPrims primGuards (concat [pFP, primDirs, importDirs])
  tdir <- maybe ghcLibDir (pure . GHC.topDir) dflagsM
  startTime <- Clock.getCurrentTime
  primMapC <-
    sequence $ HashMap.map
                 (sequence . fmap (compilePrimitive importDirs dbs tdir))
                 primMapR
  let ((bindingsMap,clsVMap),tcMap,_) =
        RWS.runRWS (mkBindings primMapC bindings clsOps unlocatable)
                   GHC.noSrcSpan
                   emptyGHC2CoreState
      (tcMap',tupTcCache)           = mkTupTyCons tcMap
      tcCache                       = makeAllTyCons tcMap' fiEnvs
      allTcCache                    = tysPrimMap `unionUniqMap` tcCache
      inScope0 = mkInScopeSet (uniqMapToUniqSet
                      ((mapUniqMap (coerce . view _1) bindingsMap) `unionUniqMap`
                       (mapUniqMap (coerce . view _1) clsMap)))
      clsMap                        = mapUniqMap (\(v,i) -> (v,GHC.noSrcSpan,GHC.Inline,mkClassSelector inScope0 allTcCache (varType v) i)) clsVMap
      allBindings                   = bindingsMap `unionVarEnv` clsMap
      topEntities'                  =
        (\m -> fst (RWS.evalRWS m GHC.noSrcSpan tcMap')) $ mapM (\(topEnt,annM,benchM) -> do
          topEnt' <- coreToName GHC.varName GHC.varUnique qualifiedNameString topEnt
          benchM' <- traverse coreToId benchM
          return (topEnt',annM,benchM')) topEntities
      topEntities''                 = map (\(topEnt,annM,benchM) -> case lookupUniqMap topEnt allBindings of
                                              Just (v,_,_,_) -> (v,annM,benchM)
                                              Nothing        -> error "This shouldn't happen"
                                          ) topEntities'
  -- Parsing / compiling primitives:
  prepTime  <- startTime `deepseq` primMapC `seq` Clock.getCurrentTime
  let prepStartDiff = reportTimeDiff prepTime startTime
  putStrLn $ "Clash: Parsing and compiling primitives took " ++ prepStartDiff

  return ( allBindings
         , allTcCache
         , tupTcCache
         , topEntities''
         , primMapC
         , customBitRepresentations
         )

mkBindings
  :: CompiledPrimMap
  -> [GHC.CoreBind]
  -- Binders
  -> [(GHC.CoreBndr,Int)]
  -- Class operations
  -> [GHC.CoreBndr]
  -- Unlocatable Expressions
  -> C2C ( BindingMap
         , VarEnv (Id,Int)
         )
mkBindings primMap bindings clsOps unlocatable = do
  bindingsList <- mapM (\case
    GHC.NonRec v e -> do
      let sp = GHC.getSrcSpan v
          inl = GHC.inlinePragmaSpec . GHC.inlinePragInfo $ GHC.idInfo v
      tm <- RWS.local (const sp) (coreToTerm primMap unlocatable e)
      v' <- coreToId v
      checkPrimitive primMap v
      return [(v', (v', sp, inl, tm))]
    GHC.Rec bs -> do
      tms <- mapM (\(v,e) -> do
                    let sp  = GHC.getSrcSpan v
                        inl = GHC.inlinePragmaSpec . GHC.inlinePragInfo $ GHC.idInfo v
                    tm <- RWS.local (const sp) (coreToTerm primMap unlocatable e)
                    v' <- coreToId v
                    checkPrimitive primMap v
                    return (v',sp,inl,tm)
                  ) bs
      case tms of
        [(v,sp,inl,tm)] -> return [(v, (v, sp, inl, tm))]
        _ -> let vsL   = map (setIdScope LocalId . view _1) tms
                 vsV   = map Var vsL
                 subst = extendGblSubstList (mkSubst emptyInScopeSet) (zip vsL vsV)
                 lbs   = zipWith (\(_,_,_,e) vL -> (vL,substTm "mkBindings" subst e)) tms vsL
                 tms1  = zipWith (\(v,sp,inl,_) (_,e) -> (v,(v,sp,inl,Letrec lbs e))) tms lbs
             in  return tms1
    ) bindings
  clsOpList    <- mapM (\(v,i) -> do
                          v' <- coreToId v
                          return (v', (v',i))
                       ) clsOps

  return (mkVarEnv (concat bindingsList), mkVarEnv clsOpList)

-- | If this CoreBndr is a primitive, check it's Haskell definition
--   for potential problems.
--
-- Warns when a primitive:
--   * isn't marked NOINLINE
--   * produces an error when evaluating its result to WHNF
--   * isn't using all its arguments
checkPrimitive :: CompiledPrimMap -> GHC.CoreBndr -> C2C ()
checkPrimitive primMap v = do
  nm <- qualifiedNameString (GHC.varName v)
  case HashMap.lookup nm primMap of
    Just (extractPrim -> Just (BlackBox _ _ _ _ _ _ _ _ _ inc r ri templ)) -> do
      let
        info = GHC.idInfo v
        inline = GHC.inlinePragmaSpec $ GHC.inlinePragInfo info
        strictness = GHC.strictnessInfo info
        ty = GHC.varType v
        (argTys,_resTy) = GHC.splitFunTys . snd . GHC.splitForAllTys $ ty
        (dmdArgs,_dmdRes) = GHC.splitStrictSig strictness
        nrOfArgs = length argTys
        loc = case GHC.getSrcLoc v of
                GHC.UnhelpfulLoc _ -> ""
                GHC.RealSrcLoc l   -> showPpr l ++ ": "
        warnIf cond msg = traceIf cond ("\n"++loc++"Warning: "++msg) return ()
      qName <- Text.unpack <$> qualifiedNameString (GHC.varName v)
      let primStr = "primitive " ++ qName ++ " "
      let usedArgs = concat [ maybe [] usedArguments r
                            , maybe [] usedArguments ri
                            , usedArguments templ
                            , concatMap (usedArguments . snd) inc
                            ]

      let warnArgs [] = return ()
          warnArgs (x:xs) = do
            warnIf (maybe False GHC.isAbsDmd (indexMaybe dmdArgs x))
              ("The Haskell implementation of " ++ primStr ++ "isn't using argument #" ++
               show (x+1) ++ ", but the corresponding primitive blackbox does.\n" ++
               "This can lead to compile failures because GHC can replace these " ++
               "arguments by an undefined value.")
            warnArgs xs

      unless (qName == "Clash.XException.errorX" || "GHC." `isPrefixOf` qName) $ do
        warnIf (inline /= GHC.NoInline)
          (primStr ++ "isn't marked NOINLINE."
          ++ "\nThis might make Clash ignore this primitive.")
        warnIf (GHC.appIsBottom strictness nrOfArgs)
          ("The Haskell implementation of " ++ primStr
          ++ "produces a result that always results in an error.\n"
          ++ "This can lead to compile failures because GHC can replace entire "
          ++ "calls to this primitive by an undefined value.")
        warnArgs usedArgs
    _ -> return ()
  where
    showPpr :: GHC.Outputable a => a -> String
    showPpr = GHC.showSDocUnsafe . GHC.ppr

mkClassSelector
  :: InScopeSet
  -> TyConMap
  -> Type
  -> Int
  -> Term
mkClassSelector inScope0 tcm ty sel = newExpr
  where
    ((tvs,dictTy:_),_) = first (lefts *** rights)
                       $ first (span (\l -> case l of Left _ -> True
                                                      _      -> False))
                       $ splitFunForallTy ty
    newExpr = case tyView dictTy of
      (TyConApp tcNm _)
        | Just tc <- lookupUniqMap tcNm tcm
        , not (isNewTypeTc tc)
        -> flip State.evalState (0 :: Int) $ do
                          dcId <- mkInternalVar inScope0 "dict" dictTy
                          let inScope1 = extendInScopeSet inScope0 dcId
                          selE <- mkSelectorCase "mkClassSelector" inScope1 tcm (Var dcId) 1 sel
                          return (mkTyLams (mkLams selE [dcId]) tvs)
      (FunTy arg res) -> flip State.evalState (0 :: Int) $ do
                           dcId <- mkInternalVar inScope0 "dict" (mkFunTy arg res)
                           return (mkTyLams (mkLams (Var dcId) [dcId]) tvs)
      _ -> flip State.evalState (0 :: Int) $ do
                           dcId <- mkInternalVar inScope0 "dict" dictTy
                           return (mkTyLams (mkLams (Var dcId) [dcId]) tvs)

mkTupTyCons :: GHC2CoreState -> (GHC2CoreState,IntMap TyConName)
mkTupTyCons tcMap = (tcMap'',tupTcCache)
  where
    tupTyCons        = GHC.boolTyCon : GHC.promotedTrueDataCon : GHC.promotedFalseDataCon
                     : map (GHC.tupleTyCon GHC.Boxed) [2..62]
    (tcNames,tcMap',_) =
      RWS.runRWS (mapM (\tc -> coreToName GHC.tyConName GHC.tyConUnique
                                          qualifiedNameString tc) tupTyCons)
                 GHC.noSrcSpan
                 tcMap
    tupTcCache       = IMS.fromList (zip [2..62] (drop 3 tcNames))
    tupHM            = listToUniqMap (zip tcNames tupTyCons)
    tcMap''          = tcMap' & tyConMap %~ (`unionUniqMap` tupHM)
