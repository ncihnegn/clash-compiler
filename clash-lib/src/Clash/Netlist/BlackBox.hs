{-|
  Copyright  :  (C) 2012-2016, University of Twente,
                    2016-2017, Myrtle Software Ltd,
                    2017     , Google Inc.
  License    :  BSD2 (see the file LICENSE)
  Maintainer :  Christiaan Baaij <christiaan.baaij@gmail.com>

  Functions to create BlackBox Contexts and fill in BlackBox templates
-}

{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}
{-# LANGUAGE TupleSections     #-}
{-# LANGUAGE ViewPatterns      #-}

module Clash.Netlist.BlackBox where

import           Control.Exception             (throw)
import           Control.Lens                  ((<<%=),(%=))
import qualified Control.Lens                  as Lens
import           Control.Monad                 (when, replicateM)
import           Control.Monad.IO.Class        (liftIO)
import           Data.Char                     (ord)
import           Data.Either                   (lefts, partitionEithers)
import qualified Data.HashMap.Lazy             as HashMap
import qualified Data.IntMap                   as IntMap
import           Data.List                     (elemIndex)
import           Data.Maybe                    (catMaybes, fromJust, fromMaybe)
import           Data.Semigroup.Monad
import qualified Data.Set                      as Set
import           Data.Text.Lazy                (fromStrict)
import qualified Data.Text.Lazy                as Text
import           Data.Text                     (unpack)
import qualified Data.Text                     as TextS
import           GHC.Stack
  (callStack, prettyCallStack)
import qualified System.Console.ANSI           as ANSI
import           System.Console.ANSI
  ( hSetSGR, SGR(SetConsoleIntensity, SetColor), Color(Magenta)
  , ConsoleIntensity(BoldIntensity), ConsoleLayer(Foreground), ColorIntensity(Vivid))
import           System.IO
  (hPutStrLn, stderr, hFlush, hIsTerminalDevice)
import           TextShow                      (showt)
import           Util                          (OverridingBool(..))

import           Clash.Annotations.Primitive
  (PrimitiveGuard(HasBlackBox, WarnNonSynthesizable, WarnAlways, DontTranslate),
   extractPrim)
import           Clash.Core.DataCon            as D (dcTag)
import           Clash.Core.FreeVars           (freeIds)
import           Clash.Core.Literal            as L (Literal (..))
import           Clash.Core.Name
  (Name (..), mkUnsafeSystemName)
import           Clash.Core.Pretty             (showPpr)
import           Clash.Core.Subst              (extendIdSubst, mkSubst, substTm)
import           Clash.Core.Term               as C
  (PrimInfo, Term (..), collectArgs, collectArgsTicks)
import           Clash.Core.Type               as C (Type (..), ConstTy (..),
                                                splitFunTys, splitFunTy)
import           Clash.Core.TyCon              as C (tyConDataCons)
import           Clash.Core.Util               (isFun, mkApps, termType)
import           Clash.Core.Var                as V
  (Id, Var (..), mkLocalId, modifyVarName)
import           Clash.Core.VarEnv
  (extendInScopeSet, mkInScopeSet, lookupVarEnv, uniqAway, unitVarSet)
import {-# SOURCE #-} Clash.Netlist
  (genComponent, mkDcApplication, mkDeclarations, mkExpr, mkNetDecl,
   mkProjection, mkSelection, mkFunApp)
import qualified Clash.Backend                 as Backend
import           Clash.Driver.Types
  (opt_primWarn, opt_color, ClashOpts)
import           Clash.Netlist.BlackBox.Types  as B
import           Clash.Netlist.BlackBox.Util   as B
import           Clash.Netlist.Id              (IdType (..))
import           Clash.Netlist.Types           as N
import           Clash.Netlist.Util            as N
import           Clash.Primitives.Types        as P
import qualified Clash.Primitives.Util         as P
import           Clash.Unique                  (lookupUniqMap')
import           Clash.Util

-- | Emits (colorized) warning to stderr
warn
  :: ClashOpts
  -> String
  -> IO ()
warn opts msg = do
  -- TODO: Put in appropriate module
  useColor <-
    case opt_color opts of
      Always -> return True
      Never  -> return False
      Auto   -> hIsTerminalDevice stderr

  hSetSGR stderr [SetConsoleIntensity BoldIntensity]
  when useColor $ hSetSGR stderr [SetColor Foreground Vivid Magenta]
  hPutStrLn stderr $ "[WARNING] " ++ msg
  hSetSGR stderr [ANSI.Reset]
  hFlush stderr

-- | Generate the context for a BlackBox instantiation.
mkBlackBoxContext
  :: TextS.Text
  -- ^ Blackbox function name
  -> Id
  -- ^ Identifier binding the primitive/blackbox application
  -> [Either Term Type]
  -- ^ Arguments of the primitive/blackbox application
  -> NetlistMonad (BlackBoxContext,[Declaration])
mkBlackBoxContext bbName resId args@(lefts -> termArgs) = do
    -- Make context inputs
    let resNm = nameOcc (varName resId)
    resTy <- unsafeCoreTypeToHWTypeM' $(curLoc) (V.varType resId)
    (imps,impDecls) <- unzip <$> mapM (mkArgument resNm) termArgs
    (funs,funDecls) <-
      mapAccumLM
        (addFunction (V.varType resId))
        IntMap.empty
        (zip termArgs [0..])

    -- Make context result
    let res = Identifier resNm Nothing

    lvl <- Lens.use curBBlvl
    (nm,_) <- Lens.use curCompNm

    -- Set "context name" to value set by `Clash.Magic.setName`, default to the
    -- name of the closest binder
    ctxName1 <- fromMaybe resNm <$> Lens.view setName
    -- Update "context name" with prefixes and suffixes set by
    -- `Clash.Magic.prefixName` and `Clash.Magic.suffixName`
    ctxName2 <- affixName ctxName1

    return ( Context bbName (res,resTy) imps funs [] lvl nm (Just ctxName2)
           , concat impDecls ++ concat funDecls
           )
  where
    addFunction resTy im (arg,i) = do
      tcm <- Lens.use tcCache
      if isFun tcm arg then do
        -- Only try to calculate function plurality when primitive actually
        -- exists. Here to prevent crashes on __INTERNAL__ primitives.
        prim <- HashMap.lookup bbName <$> Lens.use primitives
        funcPlurality <-
          case extractPrim <$> prim of
            Just (Just p) ->
              P.getFunctionPlurality p args resTy i
            _ ->
              pure 1

        curBBlvl Lens.+= 1
        (fs,ds) <- unzip <$> replicateM funcPlurality (mkFunInput resId arg)
        curBBlvl Lens.-= 1

        let im' = IntMap.insert i fs im
        return (im', concat ds)
      else
        return (im, [])

prepareBlackBox
  :: TextS.Text
  -> BlackBox
  -> BlackBoxContext
  -> NetlistMonad (BlackBox,[Declaration])
prepareBlackBox _pNm templ bbCtx =
  case verifyBlackBoxContext bbCtx templ of
    Nothing -> do
      (t2,decls) <-
        onBlackBox
          (fmap (first BBTemplate) . setSym mkUniqueIdentifier bbCtx)
          (\bbName bbHash bbFunc -> pure (BBFunction bbName bbHash bbFunc, []))
          templ
      return (t2,decls)
    Just err0 -> do
      (_,sp) <- Lens.use curCompNm
      let err1 = concat [ "Couldn't instantiate blackbox for "
                        , Data.Text.unpack (bbName bbCtx), ". Verification "
                        , "procedure reported:\n\n" ++ err0 ]
      throw (ClashException sp ($(curLoc) ++ err1) Nothing)

-- | Determine if a term represents a literal
isLiteral :: Term -> Bool
isLiteral e = case collectArgs e of
  (Data _, args)   -> all (either isLiteral (const True)) args
  (Prim _ _, args) -> all (either isLiteral (const True)) args
  (C.Literal _,_)  -> True
  _                -> False

mkArgument
  :: Identifier
  -- ^ LHS of the original let-binder
  -> Term
  -> NetlistMonad ( (Expr,HWType,Bool)
                  , [Declaration]
                  )
mkArgument bndr e = do
    tcm   <- Lens.use tcCache
    let ty = termType tcm e
    iw    <- Lens.use intWidth
    hwTyM <- fmap stripFiltered <$> N.termHWTypeM e
    let eTyMsg = "(" ++ showPpr e ++ " :: " ++ showPpr ty ++ ")"
    ((e',t,l),d) <- case hwTyM of
      Nothing
        | (Prim nm _,_) <- collectArgs e
        , nm == "Clash.Transformations.removedArg"
        -> return ((Identifier nm Nothing, Void Nothing, False),[])
        | otherwise
        -> return ((error ($(curLoc) ++ "Forced to evaluate untranslatable type: " ++ eTyMsg), Void Nothing, False), [])
      Just hwTy -> case collectArgsTicks e of
        (C.Var v,[],_) -> return ((Identifier (nameOcc (varName v)) Nothing,hwTy,False),[])
        (C.Literal (IntegerLiteral i),[],_) ->
          return ((N.Literal (Just (Signed iw,iw)) (N.NumLit i),hwTy,True),[])
        (C.Literal (IntLiteral i), [],_) ->
          return ((N.Literal (Just (Signed iw,iw)) (N.NumLit i),hwTy,True),[])
        (C.Literal (WordLiteral w), [],_) ->
          return ((N.Literal (Just (Unsigned iw,iw)) (N.NumLit w),hwTy,True),[])
        (C.Literal (CharLiteral c), [],_) ->
          return ((N.Literal (Just (Unsigned 21,21)) (N.NumLit . toInteger $ ord c),hwTy,True),[])
        (C.Literal (StringLiteral s),[],_) ->
          return ((N.Literal Nothing (N.StringLit s),hwTy,True),[])
        (C.Literal (Int64Literal i), [],_) ->
          return ((N.Literal (Just (Signed 64,64)) (N.NumLit i),hwTy,True),[])
        (C.Literal (Word64Literal i), [],_) ->
          return ((N.Literal (Just (Unsigned 64,64)) (N.NumLit i),hwTy,True),[])
        (C.Literal (NaturalLiteral n), [],_) ->
          return ((N.Literal (Just (Unsigned iw,iw)) (N.NumLit n),hwTy,True),[])
        (Prim f pinfo,args,ticks) -> withTicks ticks $ \tickDecls -> do
          (e',d) <- mkPrimitive True False (Left bndr) (f,pinfo) args ty tickDecls
          case e' of
            (Identifier _ _) -> return ((e',hwTy,False), d)
            _                -> return ((e',hwTy,isLiteral e), d)
        (Data dc, args,_) -> do
          (exprN,dcDecls) <- mkDcApplication hwTy (Left bndr) dc (lefts args)
          return ((exprN,hwTy,isLiteral e),dcDecls)
        (Case scrut ty' [alt],[],_) -> do
          (projection,decls) <- mkProjection False (Left bndr) scrut ty' alt
          return ((projection,hwTy,False),decls)
        _ ->
          return ((Identifier (error ($(curLoc) ++ "Forced to evaluate unexpected function argument: " ++ eTyMsg)) Nothing
                  ,hwTy,False),[])
    return ((e',t,l),d)

-- | Extract a compiled primitive from a guarded primitive. Emit a warning if
-- the guard wants to, or fail entirely.
extractPrimWarnOrFail
  :: HasCallStack
  => TextS.Text
  -- ^ Name of primitive
  -> NetlistMonad CompiledPrimitive
extractPrimWarnOrFail nm = do
  prim <- HashMap.lookup nm <$> Lens.use primitives
  case prim of
    Just guardedPrim ->
      -- See if we need to warn the user, or error because we encountered
      -- a primitive the user explicitly requested not to translate
      go guardedPrim
    Nothing -> do
      -- Blackbox requested, but no blackbox found at all!
      (_,sp) <- Lens.use curCompNm
      let msg = $(curLoc) ++ "No blackbox found for: " ++ unpack nm
             ++ ". Did you forget to include directories containing "
             ++ "primitives? You can use '-i/my/prim/dir' to achieve this."
             ++ (if debugIsOn then "\n\n" ++ prettyCallStack callStack ++ "\n\n" else [])
      throw (ClashException sp msg Nothing)
 where
  go
    :: GuardedCompiledPrimitive
    -> NetlistMonad CompiledPrimitive
  go (HasBlackBox cp) =
    return cp

  go DontTranslate = do
    (_,sp) <- Lens.use curCompNm
    let msg = $(curLoc) ++ "Clash was forced to translate '" ++ unpack nm
           ++ "', but this value was marked with DontTranslate. Did you forget"
           ++ " to include a blackbox for one of the constructs using this?"
           ++ (if debugIsOn then "\n\n" ++ prettyCallStack callStack ++ "\n\n" else [])
    throw (ClashException sp msg Nothing)

  go (WarnAlways warning cp) = do
    primWarn <- opt_primWarn <$> Lens.use clashOpts
    seen <- Set.member nm <$> Lens.use seenPrimitives
    opts <- Lens.use clashOpts

    when (primWarn && not seen)
      $ liftIO
      $ warn opts
      $ "Dubious primitive instantiation for "
     ++ unpack nm
     ++ ": "
     ++ warning
     ++ " (disable with -fclash-no-prim-warn)"

    seenPrimitives %= Set.insert nm

    return cp

  go (WarnNonSynthesizable warning cp) = do
    isTB <- Lens.use isTestBench
    if isTB then return cp else go (WarnAlways warning cp)


mkPrimitive
  :: Bool
  -- ^ Put BlackBox expression in parenthesis
  -> Bool
  -- ^ Treat BlackBox expression as declaration
  -> Either Identifier Id
  -- ^ Id to assign the result to
  -> (TextS.Text, PrimInfo)
  -- ^ Name and info of primitive
  -> [Either Term Type]
  -- ^ Arguments
  -> Type
  -- ^ Result type
  -> [Declaration]
  -- ^ Tick declarations
  -> NetlistMonad (Expr,[Declaration])
mkPrimitive bbEParen bbEasD dst (nm,pinfo) args ty tickDecls =
  go =<< extractPrimWarnOrFail nm
  where
    go
      :: CompiledPrimitive
      -> NetlistMonad (Expr, [Declaration])
    go =
      \case
        P.BlackBoxHaskell bbName wf funcName (_fHash, func) -> do
          bbFunRes <- func bbEasD nm args ty
          case bbFunRes of
            Left err -> do
              -- Blackbox template function returned an error:
              let err' = unwords [ $(curLoc) ++ "Could not create blackbox"
                                 , "template using", show funcName, "for"
                                 , show bbName ++ ".", "Function reported: \n\n"
                                 , err ]
              (_,sp) <- Lens.use curCompNm
              throw (ClashException sp err' Nothing)
            Right (BlackBoxMeta {..}, bbTemplate) ->
              -- Blackbox template generation succesful. Rerun 'go', but this time
              -- around with a 'normal' @BlackBox@
              go (P.BlackBox
                    bbName wf bbRenderVoid bbKind () bbOutputReg bbLibrary bbImports
                    bbFunctionPlurality bbIncludes Nothing Nothing bbTemplate)
        p@P.BlackBox {} ->
          case kind p of
            TDecl -> do
              let tempD = template p
                  pNm = name p
              resM <- resBndr True dst
              case resM of
                Just (dst',dstNm,dstDecl) -> do
                  (bbCtx,ctxDcls)   <- mkBlackBoxContext nm dst' args
                  (templ,templDecl) <- prepareBlackBox pNm tempD bbCtx
                  let bbDecl = N.BlackBoxD pNm (libraries p) (imports p)
                                           (includes p) templ bbCtx
                  return (Identifier dstNm Nothing,dstDecl ++ ctxDcls ++ templDecl ++ tickDecls ++ [bbDecl])

                -- Render declarations as a Noop when requested
                Nothing | RenderVoid <- renderVoid p -> do
                  let dst1 = mkLocalId ty (mkUnsafeSystemName "__VOID_TDECL_NOOP__" 0)
                  (bbCtx,ctxDcls) <- mkBlackBoxContext nm dst1 args
                  (templ,templDecl) <- prepareBlackBox pNm tempD bbCtx
                  let bbDecl = N.BlackBoxD pNm (libraries p) (imports p)
                                           (includes p) templ bbCtx
                  return (Noop, ctxDcls ++ templDecl ++ tickDecls ++ [bbDecl])

                -- Otherwise don't render them
                Nothing -> return (Identifier "__VOID_TDECL__" Nothing,[])
            TExpr -> do
              let tempE = template p
                  pNm = name p
              if bbEasD
                then do
                  resM <- resBndr True dst
                  case resM of
                    Just (dst',dstNm,dstDecl) -> do
                      (bbCtx,ctxDcls)     <- mkBlackBoxContext nm dst' args
                      (bbTempl,templDecl) <- prepareBlackBox pNm tempE bbCtx
                      let tmpAssgn = Assignment dstNm
                                        (BlackBoxE pNm (libraries p) (imports p)
                                                   (includes p) bbTempl bbCtx
                                                   bbEParen)
                      return (Identifier dstNm Nothing, dstDecl ++ ctxDcls ++ templDecl ++ [tmpAssgn])

                    -- Render expression as a Noop when requested
                    Nothing | RenderVoid <- renderVoid p -> do
                      let dst1 = mkLocalId ty (mkUnsafeSystemName "__VOID_TEXPRD_NOOP__" 0)
                      (bbCtx,ctxDcls) <- mkBlackBoxContext nm dst1 args
                      (templ,templDecl) <- prepareBlackBox pNm tempE bbCtx
                      let bbDecl = N.BlackBoxD pNm (libraries p) (imports p)
                                               (includes p) templ bbCtx
                      return (Noop, ctxDcls ++ templDecl ++ tickDecls ++ [bbDecl])

                    -- Otherwise don't render them
                    Nothing -> return (Identifier "__VOID_TEXPRD__" Nothing,[])
                else do
                  resM <- resBndr False dst
                  case resM of
                    Just (dst',_,_) -> do
                      (bbCtx,ctxDcls)      <- mkBlackBoxContext nm dst' args
                      (bbTempl,templDecl0) <- prepareBlackBox pNm tempE bbCtx
                      let templDecl1 = case nm of
                            "Clash.Sized.Internal.BitVector.fromInteger#"
                              | [N.Literal _ (NumLit _), N.Literal _ _, N.Literal _ _] <- extractLiterals bbCtx -> []
                            "Clash.Sized.Internal.BitVector.fromInteger##"
                              | [N.Literal _ _, N.Literal _ _] <- extractLiterals bbCtx -> []
                            "Clash.Sized.Internal.Index.fromInteger#"
                              | [N.Literal _ (NumLit _), N.Literal _ _] <- extractLiterals bbCtx -> []
                            "Clash.Sized.Internal.Signed.fromInteger#"
                              | [N.Literal _ (NumLit _), N.Literal _ _] <- extractLiterals bbCtx -> []
                            "Clash.Sized.Internal.Unsigned.fromInteger#"
                              | [N.Literal _ (NumLit _), N.Literal _ _] <- extractLiterals bbCtx -> []
                            _ -> templDecl0
                      return (BlackBoxE pNm (libraries p) (imports p) (includes p) bbTempl bbCtx bbEParen,ctxDcls ++ templDecl1)
                    -- Render expression as a Noop when requested
                    Nothing | RenderVoid <- renderVoid p -> do
                      let dst1 = mkLocalId ty (mkUnsafeSystemName "__VOID_TEXPRE_NOOP__" 0)
                      (bbCtx,ctxDcls) <- mkBlackBoxContext nm dst1 args
                      (templ,templDecl) <- prepareBlackBox pNm tempE bbCtx
                      let bbDecl = N.BlackBoxD pNm (libraries p) (imports p)
                                               (includes p) templ bbCtx
                      return (Noop, ctxDcls ++ templDecl ++ tickDecls ++ [bbDecl])

                    -- Otherwise don't render them
                    Nothing -> return (Identifier "__VOID__" Nothing,[])
        P.Primitive pNm _ _
          | pNm == "GHC.Prim.tagToEnum#" -> do
              hwTy <- N.unsafeCoreTypeToHWTypeM' $(curLoc) ty
              case args of
                [Right (ConstTy (TyCon tcN)), Left (C.Literal (IntLiteral i))] -> do
                  tcm <- Lens.use tcCache
                  let dcs = tyConDataCons (tcm `lookupUniqMap'` tcN)
                      dc  = dcs !! fromInteger i
                  (exprN,dcDecls) <- mkDcApplication hwTy dst dc []
                  return (exprN,dcDecls)
                [Right _, Left scrut] -> do
                  tcm     <- Lens.use tcCache
                  let scrutTy = termType tcm scrut
                  (scrutExpr,scrutDecls) <- mkExpr False (Left "c$tte_rhs") scrutTy scrut
                  case scrutExpr of
                    Identifier id_ Nothing -> return (DataTag hwTy (Left id_),scrutDecls)
                    _ -> do
                      scrutHTy <- unsafeCoreTypeToHWTypeM' $(curLoc) scrutTy
                      tmpRhs <- mkUniqueIdentifier Extended "c$tte_rhs"
                      let netDeclRhs   = NetDecl Nothing tmpRhs scrutHTy
                          netAssignRhs = Assignment tmpRhs scrutExpr
                      return (DataTag hwTy (Left tmpRhs),[netDeclRhs,netAssignRhs] ++ scrutDecls)
                _ -> error $ $(curLoc) ++ "tagToEnum: " ++ show (map (either showPpr showPpr) args)
          | pNm == "GHC.Prim.dataToTag#" -> case args of
              [Right _,Left (Data dc)] -> do
                iw <- Lens.use intWidth
                return (N.Literal (Just (Signed iw,iw)) (NumLit $ toInteger $ dcTag dc - 1),[])
              [Right _,Left scrut] -> do
                tcm      <- Lens.use tcCache
                let scrutTy = termType tcm scrut
                scrutHTy <- unsafeCoreTypeToHWTypeM' $(curLoc) scrutTy
                (scrutExpr,scrutDecls) <- mkExpr False (Left "c$dtt_rhs") scrutTy scrut
                case scrutExpr of
                  Identifier id_ Nothing -> return (DataTag scrutHTy (Right id_),scrutDecls)
                  _ -> do
                    tmpRhs  <- mkUniqueIdentifier Extended "c$dtt_rhs"
                    let netDeclRhs   = NetDecl Nothing tmpRhs scrutHTy
                        netAssignRhs = Assignment tmpRhs scrutExpr
                    return (DataTag scrutHTy (Right tmpRhs),[netDeclRhs,netAssignRhs] ++ scrutDecls)
              _ -> error $ $(curLoc) ++ "dataToTag: " ++ show (map (either showPpr showPpr) args)
          | otherwise ->
              return (BlackBoxE "" [] [] []
                        (BBTemplate [Text $ mconcat ["NO_TRANSLATION_FOR:",fromStrict pNm]])
                        (emptyBBContext pNm) False,[])

    resBndr
      :: Bool
      -> (Either Identifier Id)
      -> NetlistMonad (Maybe (Id,Identifier,[Declaration]))
      -- Nothing when the binder would have type `Void`
    resBndr mkDec dst' = do
      resHwTy <- unsafeCoreTypeToHWTypeM' $(curLoc) ty
      if isVoid resHwTy then
        pure Nothing
      else
        case dst' of
          Left dstL -> case mkDec of
            False -> do
              -- TODO: check that it's okay to use `mkUnsafeSystemName`
              let nm' = mkUnsafeSystemName dstL 0
                  id_ = mkLocalId ty nm'
              return (Just (id_,dstL,[]))
            True -> do
              nm1 <- extendIdentifier Extended dstL "_res"
              nm2 <- mkUniqueIdentifier Extended nm1
              -- TODO: check that it's okay to use `mkUnsafeInternalName`
              let nm3 = mkUnsafeSystemName nm2 0
                  id_ = mkLocalId ty nm3
              idDeclM <- mkNetDecl (id_,mkApps (Prim nm pinfo) args)
              case idDeclM of
                Nothing     -> return Nothing
                Just idDecl -> return (Just (id_,nm2,[idDecl]))
          Right dstR -> return (Just (dstR,nameOcc . varName $ dstR,[]))

-- | Create an template instantiation text and a partial blackbox content for an
-- argument term, given that the term is a function. Errors if the term is not
-- a function
mkFunInput
  :: HasCallStack
  => Id
  -- ^ Identifier binding the encompassing primitive/blackbox application
  -> Term
  -- ^ The function argument term
  -> NetlistMonad
      ((Either BlackBox (Identifier,[Declaration])
       ,WireOrReg
       ,[BlackBoxTemplate]
       ,[BlackBoxTemplate]
       ,[((TextS.Text,TextS.Text),BlackBox)]
       ,BlackBoxContext)
      ,[Declaration])
mkFunInput resId e =
 let (appE,args,ticks) = collectArgsTicks e
 in  withTicks ticks $ \tickDecls -> do
  tcm <- Lens.use tcCache
  -- TODO: Rewrite this function to use blackbox functions. Right now it
  -- TODO: generates strings that are later parsed/interpreted again. Silly!
  (bbCtx,dcls) <- mkBlackBoxContext "__INTERNAL__" resId args
  templ <- case appE of
            Prim nm _ -> do
              bb  <- extractPrimWarnOrFail nm
              case bb of
                P.BlackBox {..} ->
                  pure (Left (kind,outputReg,libraries,imports,includes,nm,template))
                P.Primitive pn _ pt ->
                  error $ $(curLoc) ++ "Unexpected blackbox type: "
                                    ++ "Primitive " ++ show pn
                                    ++ " " ++ show pt
                P.BlackBoxHaskell pName _workInfo fName (_, func) -> do
                  -- Determine result type of this blackbox. If it's not a
                  -- function, simply use its term type.
                  let
                    resTy0 = termType tcm e
                    resTy1 =
                      case splitFunTy tcm resTy0 of
                        Just (_, t) -> t
                        Nothing -> resTy0

                  bbhRes <- func True pName args resTy1
                  case bbhRes of
                    Left err ->
                      error $ $(curLoc) ++ show fName ++ " yielded an error: "
                                        ++ err
                    Right (BlackBoxMeta{..}, template) ->
                      pure $
                        Left ( bbKind, bbOutputReg, bbLibrary, bbImports
                             , bbIncludes, pName, template)
            Data dc -> do
              let eTy = termType tcm e
                  (_,resTy) = splitFunTys tcm eTy

              resHTyM0 <- coreTypeToHWTypeM resTy
              let resHTyM1 = (\fHwty -> (stripFiltered fHwty, flattenFiltered fHwty)) <$> resHTyM0

              case resHTyM1 of
                -- Special case where coreTypeToHWTypeM determined a type to
                -- be completely transparent.
                Just (_resHTy, areVoids@[countEq False -> 1]) -> do
                  let nonVoidArgI = fromJust (elemIndex False (head areVoids))
                  let arg = TextS.concat ["~ARG[", showt nonVoidArgI, "]"]
                  let assign = Assignment "~RESULT" (Identifier arg Nothing)
                  return (Right (("", tickDecls ++ [assign]), Wire))

                -- Because we filter void constructs, the argument indices and
                -- the field indices don't necessarily correspond anymore. We
                -- use the result of coreTypeToHWTypeM to figure out what the
                -- original indices are. Please see the documentation in
                -- Clash.Netlist.Util.mkADT for more information.
                Just (resHTy@(SP _ _), areVoids0) -> do
                  let
                      dcI       = dcTag dc - 1
                      areVoids1 = indexNote ($(curLoc) ++ "No areVoids with index: " ++ show dcI) areVoids0 dcI
                      dcInps    = [Identifier (TextS.pack ("~ARG[" ++ show x ++ "]")) Nothing | x <- originalIndices areVoids1]
                      dcApp     = DataCon resHTy (DC (resHTy,dcI)) dcInps
                      dcAss     = Assignment "~RESULT" dcApp
                  return (Right (("",tickDecls ++ [dcAss]),Wire))

                -- CustomSP the same as SP, but with a user-defined bit
                -- level representation
                Just (resHTy@(CustomSP {}), areVoids0) -> do
                  let
                      dcI       = dcTag dc - 1
                      areVoids1 = indexNote ($(curLoc) ++ "No areVoids with index: " ++ show dcI) areVoids0 dcI
                      dcInps    = [Identifier (TextS.pack ("~ARG[" ++ show x ++ "]")) Nothing | x <- originalIndices areVoids1]
                      dcApp     = DataCon resHTy (DC (resHTy,dcI)) dcInps
                      dcAss     = Assignment "~RESULT" dcApp
                  return (Right (("",tickDecls ++ [dcAss]),Wire))

                -- Like SP, we have to retrieve the index BEFORE filtering voids
                Just (resHTy@(Product _ _ _), areVoids0) -> do
                  let areVoids1 = head areVoids0
                      dcInps    = [ Identifier (TextS.pack ("~ARG[" ++ show x ++ "]")) Nothing | x <- originalIndices areVoids1]
                      dcApp     = DataCon resHTy (DC (resHTy,0)) dcInps
                      dcAss     = Assignment "~RESULT" dcApp
                  return (Right (("",tickDecls ++ [dcAss]),Wire))

                -- Vectors never have defined areVoids (or all set to False), as
                -- it would be converted to Void otherwise. We can therefore
                -- safely ignore it:
                Just (resHTy@(Vector _ _), _areVoids) -> do
                  let dcInps = [ Identifier (TextS.pack ("~ARG[" ++ show x ++ "]")) Nothing | x <- [(1::Int)..2] ]
                      dcApp  = DataCon resHTy (DC (resHTy,1)) dcInps
                      dcAss  = Assignment "~RESULT" dcApp
                  return (Right (("",tickDecls ++ [dcAss]),Wire))

                -- Sum types OR a Sum type after filtering empty types:
                Just (resHTy@(Sum _ _), _areVoids) -> do
                  let dcI   = dcTag dc - 1
                      dcApp = DataCon resHTy (DC (resHTy,dcI)) []
                      dcAss = Assignment "~RESULT" dcApp
                  return (Right (("",tickDecls ++ [dcAss]),Wire))

                -- Same as Sum, but with user defined bit level representation
                Just (resHTy@(CustomSum {}), _areVoids) -> do
                  let dcI   = dcTag dc - 1
                      dcApp = DataCon resHTy (DC (resHTy,dcI)) []
                      dcAss = Assignment "~RESULT" dcApp
                  return (Right (("",tickDecls ++ [dcAss]),Wire))

                Just (Void {}, _areVoids) ->
                  return (error $ $(curLoc) ++ "Encountered Void in mkFunInput."
                                            ++ " This is a bug in Clash.")

                _ -> error $ $(curLoc) ++ "Cannot make function input for: " ++ showPpr e
            C.Var fun -> do
              topAnns <- Lens.use topEntityAnns
              case lookupVarEnv fun topAnns of
                Just _ ->
                  error $ $(curLoc) ++ "Cannot make function input for partially applied Synthesize-annotated: " ++ showPpr e
                _ -> do
                  normalized <- Lens.use bindings
                  case lookupVarEnv fun normalized of
                    Just _ -> do
                      (wereVoids,_,_,N.Component compName compInps [snd -> compOutp] _) <-
                        preserveVarEnv $ genComponent fun

                      let inpAssign (i, t) e' = (Identifier i Nothing, In, t, e')
                          inpVar i            = TextS.pack ("~VAR[arg" ++ show i ++ "][" ++ show i ++ "]")
                          inpVars             = [Identifier (inpVar i)  Nothing | i <- originalIndices wereVoids]
                          inpAssigns          = zipWith inpAssign compInps inpVars
                          outpAssign          = ( Identifier (fst compOutp) Nothing
                                                , Out
                                                , snd compOutp
                                                , Identifier "~RESULT" Nothing )
                      i <- varCount <<%= (+1)
                      let instLabel     = TextS.concat [compName,TextS.pack ("_" ++ show i)]
                          instDecl      = InstDecl Entity Nothing compName instLabel [] (outpAssign:inpAssigns)
                      return (Right (("",tickDecls ++ [instDecl]),Wire))
                    Nothing -> error $ $(curLoc) ++ "Cannot make function input for: " ++ showPpr e
            C.Lam {} -> do
              let is0 = mkInScopeSet (Lens.foldMapOf freeIds unitVarSet appE)
              either Left (Right . first (second (tickDecls ++))) <$> go is0 0 appE
            _ -> error $ $(curLoc) ++ "Cannot make function input for: " ++ showPpr e
  case templ of
    Left (TDecl,oreg,libs,imps,inc,_,templ') -> do
      (l',templDecl)
        <- onBlackBox
            (fmap (first BBTemplate) . setSym mkUniqueIdentifier bbCtx)
            (\bbName bbHash bbFunc -> pure $ (BBFunction bbName bbHash bbFunc, []))
            templ'
      return ((Left l',if oreg then Reg else Wire,libs,imps,inc,bbCtx),dcls ++ templDecl)
    Left (TExpr,_,libs,imps,inc,nm,templ') -> do
      onBlackBox
        (\t -> do t' <- getMon (prettyBlackBox t)
                  let assn = Assignment "~RESULT" (Identifier (Text.toStrict t') Nothing)
                  return ((Right ("",[assn]),Wire,libs,imps,inc,bbCtx),dcls))
        (\bbName bbHash (TemplateFunction k g _) -> do
          let f' bbCtx' = do
                let assn = Assignment "~RESULT"
                            (BlackBoxE nm libs imps inc templ' bbCtx' False)
                p <- getMon (Backend.blockDecl "" [assn])
                return p
          return ((Left (BBFunction bbName bbHash (TemplateFunction k g f'))
                  ,Wire
                  ,[]
                  ,[]
                  ,[]
                  ,bbCtx
                  )
                 ,dcls
                 )
        )
        templ'
    Right (decl,wr) ->
      return ((Right decl,wr,[],[],[],bbCtx),dcls)
  where
    goExpr app@(collectArgsTicks -> (C.Var fun,args@(_:_),ticks)) = do
      let (tmArgs,tyArgs) = partitionEithers args
      if null tyArgs
        then
          withTicks ticks $ \tickDecls -> do
            appDecls <- mkFunApp "~RESULT" fun tmArgs tickDecls
            nm <- mkUniqueIdentifier Basic "block"
            return (Right ((nm,appDecls),Wire))
        else do
          (_,sp) <- Lens.use curCompNm
          throw (ClashException sp ($(curLoc) ++ "Not in normal form: Var-application with Type arguments:\n\n" ++ showPpr app) Nothing)
    goExpr e' = do
      tcm <- Lens.use tcCache
      let eType = termType tcm e'
      (appExpr,appDecls) <- mkExpr False (Left "c$bb_res") eType e'
      let assn = Assignment "~RESULT" appExpr
      nm <- if null appDecls
               then return ""
               else mkUniqueIdentifier Basic "block"
      return (Right ((nm,appDecls ++ [assn]),Wire))

    go is0 n (Lam id_ e') = do
      lvl <- Lens.use curBBlvl
      let nm    = TextS.concat
                    ["~ARGN[",TextS.pack (show lvl),"][",TextS.pack (show n),"]"]
          v'    = uniqAway is0 (modifyVarName (\v -> v {nameOcc = nm}) id_)
          subst = extendIdSubst (mkSubst is0) id_ (C.Var v')
          e''   = substTm "mkFunInput.goLam" subst e'
          is1   = extendInScopeSet is0 v'
      go is1 (n+(1::Int)) e''

    go _ _ (C.Var v) = do
      let assn = Assignment "~RESULT" (Identifier (nameOcc (varName v)) Nothing)
      return (Right (("",[assn]),Wire))

    go _ _ (Case scrut ty [alt]) = do
      (projection,decls) <- mkProjection False (Left "c$bb_res") scrut ty alt
      let assn = Assignment "~RESULT" projection
      nm <- if null decls
               then return ""
               else mkUniqueIdentifier Basic "projection"
      return (Right ((nm,decls ++ [assn]),Wire))

    go _ _ (Case scrut ty alts@(_:_:_)) = do
      -- TODO: check that it's okay to use `mkUnsafeSystemName`
      let resId'  = resId {varName = mkUnsafeSystemName "~RESULT" 0}
      selectionDecls <- mkSelection (Right resId') scrut ty alts []
      nm <- mkUniqueIdentifier Basic "selection"
      tcm <- Lens.use tcCache
      let scrutTy = termType tcm scrut
      scrutHTy <- unsafeCoreTypeToHWTypeM' $(curLoc) scrutTy
      ite <- Lens.use backEndITE
      let wr = case iteAlts scrutHTy alts of
                 Just _ | ite -> Wire
                 _ -> Reg
      return (Right ((nm,selectionDecls),wr))

    go is0 _ e'@(Letrec {}) = do
      tcm <- Lens.use tcCache
      let normE = splitNormalized tcm e'
      (_,[],[],_,[],binders,resultM) <- case normE of
        Right norm -> mkUniqueNormalized is0 Nothing norm
        Left err -> error err
      case resultM of
        Just result -> do
          let binders' = map (\(id_,tm) -> (goR result id_,tm)) binders
          netDecls <- fmap catMaybes . mapM mkNetDecl $ filter ((/= result) . fst) binders
          decls    <- concat <$> mapM (uncurry mkDeclarations) binders'
          Just (NetDecl' _ rw _ _ _) <- mkNetDecl . head $ filter ((==result) . fst) binders
          nm <- mkUniqueIdentifier Basic "fun"
          return (Right ((nm,netDecls ++ decls),rw))
        Nothing -> return (Right (("",[]),Wire))
      where
        -- TODO: check that it's okay to use `mkUnsafeSystemName`
        goR r id_ | id_ == r  = id_ {varName = mkUnsafeSystemName "~RESULT" 0}
                  | otherwise = id_

    go is0 n (Tick _ e') = go is0 n e'

    go _ _ e'@(App {}) = goExpr e'
    go _ _ e'@(C.Data {}) = goExpr e'
    go _ _ e'@(C.Literal {}) = goExpr e'
    go _ _ e'@(Cast {}) = goExpr e'
    go _ _ e'@(Prim {}) = goExpr e'
    go _ _ e'@(TyApp {}) = goExpr e'

    go _ _ e'@(Case _ _ []) =
      error $ $(curLoc) ++ "Cannot make function input for case without alternatives: " ++ show e'

    go _ _ e'@(TyLam {}) =
      error $ $(curLoc) ++ "Cannot make function input for TyLam: " ++ show e'
