# Changelog for [`clash-prelude` package](http://hackage.haskell.org/package/clash-prelude)

## 1.0.0 *September 3rd 2019*
* New features:
  * API changes: check the migration guide at the end of `Clash.Tutorial`
  * All memory elements now have an (implicit) enable line; "Gated" clocks have
    been removed as the clock wasn't actually gated, but implemented as an
    enable line.
  * Circuit domains are now configurable in:
    * (old) The clock period
    * (new) Clock edge on which memory elements latch their inputs
      (rising edge or falling edge)
    * (new) Whether the reset port of a memory element is level sensitive
      (asynchronous reset) or edge sensitive (synchronous reset)
    * (new) Whether the reset port of a memory element is active-high or
      active-low (negated reset)
    * (new) Whether memory element power on in a configurable/defined state
      (common on FPGAs) or in an undefined state (ASICs)

    * See the [blog post](https://clash-lang.org/blog/0005-synthesis-domain/) on this new feature
  * Data types can now be given custom bit-representations: http://hackage.haskell.org/package/clash-prelude/docs/Clash-Annotations-BitRepresentation.html
  * Annotate expressions with attributes that persist in the generated HDL,
    e.g. synthesis directives: http://hackage.haskell.org/package/clash-prelude/docs/Clash-Annotations-SynthesisAttributes.html
  * Control (System)Verilog module instance, and VHDL entity instantiation names
    in generated code: http://hackage.haskell.org/package/clash-prelude/docs/Clash-Magic.html
  * Much improved infrastructure for handling of unknown values: defined spine,
    but unknown leafs: http://hackage.haskell.org/package/clash-prelude/docs/Clash-XException.html#t:NFDataX
  * Experimental: Multiple hidden clocks. Can be enabled by compiling
    `clash-prelude` with `-fmultiple-hidden`
  * Experimental: Limited GADT support (pattern matching on vectors, or custom
    GADTs as longs as their usage can be statically removed; no support of
    recursive GADTs)
  * Experimental: Use regular Haskell functions to generate HDL black boxes for
    primitives (in an addition to existing string templates for HDL black boxes)
    See for example: http://hackage.haskell.org/package/clash-lib/docs/Clash-Primitives-Intel-ClockGen.html

* Fixes issues:
  * [#316](https://github.com/clash-lang/clash-prelude/issues/316)
  * [#319](https://github.com/clash-lang/clash-prelude/issues/319)
  * [#323](https://github.com/clash-lang/clash-prelude/issues/323)
  * [#324](https://github.com/clash-lang/clash-prelude/issues/324)
  * [#329](https://github.com/clash-lang/clash-prelude/issues/329)
  * [#331](https://github.com/clash-lang/clash-prelude/issues/331)
  * [#332](https://github.com/clash-lang/clash-prelude/issues/332)
  * [#335](https://github.com/clash-lang/clash-prelude/issues/335)
  * [#348](https://github.com/clash-lang/clash-prelude/issues/348)
  * [#349](https://github.com/clash-lang/clash-prelude/issues/349)
  * [#350](https://github.com/clash-lang/clash-prelude/issues/350)
  * [#351](https://github.com/clash-lang/clash-prelude/issues/351)
  * [#352](https://github.com/clash-lang/clash-prelude/issues/352)
  * [#353](https://github.com/clash-lang/clash-prelude/issues/353)
  * [#358](https://github.com/clash-lang/clash-prelude/issues/358)
  * [#359](https://github.com/clash-lang/clash-prelude/issues/359)
  * [#363](https://github.com/clash-lang/clash-prelude/issues/363)
  * [#364](https://github.com/clash-lang/clash-prelude/issues/364)
  * [#365](https://github.com/clash-lang/clash-prelude/issues/365)
  * [#371](https://github.com/clash-lang/clash-prelude/issues/371)
  * [#372](https://github.com/clash-lang/clash-prelude/issues/372)
  * [#373](https://github.com/clash-lang/clash-prelude/issues/373)
  * [#378](https://github.com/clash-lang/clash-prelude/issues/378)
  * [#380](https://github.com/clash-lang/clash-prelude/issues/380)
  * [#381](https://github.com/clash-lang/clash-prelude/issues/381)
  * [#382](https://github.com/clash-lang/clash-prelude/issues/382)
  * [#383](https://github.com/clash-lang/clash-prelude/issues/383)
  * [#387](https://github.com/clash-lang/clash-prelude/issues/387)
  * [#393](https://github.com/clash-lang/clash-prelude/issues/393)
  * [#396](https://github.com/clash-lang/clash-prelude/issues/396)
  * [#398](https://github.com/clash-lang/clash-prelude/issues/398)
  * [#399](https://github.com/clash-lang/clash-prelude/issues/399)
  * [#401](https://github.com/clash-lang/clash-prelude/issues/401)
  * [#403](https://github.com/clash-lang/clash-prelude/issues/403)
  * [#407](https://github.com/clash-lang/clash-prelude/issues/407)
  * [#412](https://github.com/clash-lang/clash-prelude/issues/412)
  * [#413](https://github.com/clash-lang/clash-prelude/issues/413)
  * [#420](https://github.com/clash-lang/clash-prelude/issues/420)
  * [#422](https://github.com/clash-lang/clash-prelude/issues/422)
  * [#423](https://github.com/clash-lang/clash-prelude/issues/423)
  * [#424](https://github.com/clash-lang/clash-prelude/issues/424)
  * [#438](https://github.com/clash-lang/clash-prelude/issues/438)
  * [#450](https://github.com/clash-lang/clash-prelude/issues/450)
  * [#452](https://github.com/clash-lang/clash-prelude/issues/452)
  * [#455](https://github.com/clash-lang/clash-prelude/issues/455)
  * [#460](https://github.com/clash-lang/clash-prelude/issues/460)
  * [#461](https://github.com/clash-lang/clash-prelude/issues/461)
  * [#463](https://github.com/clash-lang/clash-prelude/issues/463)
  * [#468](https://github.com/clash-lang/clash-prelude/issues/468)
  * [#475](https://github.com/clash-lang/clash-prelude/issues/475)
  * [#476](https://github.com/clash-lang/clash-prelude/issues/476)
  * [#500](https://github.com/clash-lang/clash-prelude/issues/500)
  * [#507](https://github.com/clash-lang/clash-prelude/issues/507)
  * [#512](https://github.com/clash-lang/clash-prelude/issues/512)
  * [#516](https://github.com/clash-lang/clash-prelude/issues/516)
  * [#517](https://github.com/clash-lang/clash-prelude/issues/517)
  * [#526](https://github.com/clash-lang/clash-prelude/issues/526)
  * [#556](https://github.com/clash-lang/clash-prelude/issues/556)
  * [#560](https://github.com/clash-lang/clash-prelude/issues/560)
  * [#566](https://github.com/clash-lang/clash-prelude/issues/566)
  * [#567](https://github.com/clash-lang/clash-prelude/issues/567)
  * [#569](https://github.com/clash-lang/clash-prelude/issues/569)
  * [#573](https://github.com/clash-lang/clash-prelude/issues/573)
  * [#575](https://github.com/clash-lang/clash-prelude/issues/575)
  * [#581](https://github.com/clash-lang/clash-prelude/issues/581)
  * [#582](https://github.com/clash-lang/clash-prelude/issues/582)
  * [#586](https://github.com/clash-lang/clash-prelude/issues/586)
  * [#588](https://github.com/clash-lang/clash-prelude/issues/588)
  * [#591](https://github.com/clash-lang/clash-prelude/issues/591)
  * [#596](https://github.com/clash-lang/clash-prelude/issues/596)
  * [#601](https://github.com/clash-lang/clash-prelude/issues/601)
  * [#607](https://github.com/clash-lang/clash-prelude/issues/607)
  * [#629](https://github.com/clash-lang/clash-prelude/issues/629)
  * [#637](https://github.com/clash-lang/clash-prelude/issues/637)
  * [#644](https://github.com/clash-lang/clash-prelude/issues/644)
  * [#647](https://github.com/clash-lang/clash-prelude/issues/647)
  * [#661](https://github.com/clash-lang/clash-prelude/issues/661)
  * [#668](https://github.com/clash-lang/clash-prelude/issues/668)
  * [#677](https://github.com/clash-lang/clash-prelude/issues/677)
  * [#678](https://github.com/clash-lang/clash-prelude/issues/678)
  * [#682](https://github.com/clash-lang/clash-prelude/issues/682)
  * [#691](https://github.com/clash-lang/clash-prelude/issues/691)
  * [#703](https://github.com/clash-lang/clash-prelude/issues/703)
  * [#713](https://github.com/clash-lang/clash-prelude/issues/713)
  * [#715](https://github.com/clash-lang/clash-prelude/issues/715)
  * [#727](https://github.com/clash-lang/clash-prelude/issues/727)
  * [#730](https://github.com/clash-lang/clash-prelude/issues/730)
  * [#736](https://github.com/clash-lang/clash-prelude/issues/736)
  * [#738](https://github.com/clash-lang/clash-prelude/issues/738)

## 0.99.3 *July 26th 2018*
* Bundle and BitPack instances up to and including 62-tuples
* Handle undefined writes to RAM properly
* Handle undefined clock enables properly

## 0.99.1 *May 12th 2018*
* Support for `ghc-typelits-natnormalise-0.6.1`
* `Lift` instances for `TopEntity` and `PortName`
* `InlinePrimitive` support: specify HDL primitives inline with Haskell code

## 0.99 *March 31st 2018*
* Major API overhaul: check the migration guide at the end of `Clash.Tutorial`
* New features:
  * Explicit clock and reset arguments
  * Rename `CLaSH` to `Clash`
  * Implicit/`Hidden` clock and reset arguments using a combination of
    `reflection` and `ImplicitParams`.
  * Large overhaul of `TopEntity`  annotations
  * PLL and other clock sources can now be instantiated using regular functions:
    `Clash.Intel.ClockGen` and `Clash.Xilinx.ClockGen`.
  * DDR registers:
    * Generic/ASIC: `Clash.Explicit.DDR`
    * Intel: `Clash.Intel.DDR`
    * Xilinx: `Clash.Intel.Xilinx`
  * `Bit` is now a `newtype` instead of a `type` synonym and will be mapped to
    a HDL scalar instead of an array of one (e.g `std_logic` instead of
    `std_logic_vector(0 downto 0)`)

## 0.11.2
* New features:
  * Add `riseEvery`: Give a pulse every @n@ clock cycles. (Thanks to @thoughtpolice)
  * Add `oscillate`: Oscillate a @'Bool'@ with a given half-period of cycles. (Thanks to @thoughtpolice)
* Fixes bugs:
  * Eagerness bug in `regEn` [#104](https://github.com/clash-lang/clash-prelude/issues/104) (Thanks to @cbiffle)

## 0.11.1
* Changes:
  * Bundle instance for `()` behaves like a product-type instance [#96](https://github.com/clash-lang/clash-prelude/issues/96)
* Fixes bugs:
  * Ensure that `fold` gets correctly type-applied in `Vec.==` [#202](https://github.com/clash-lang/clash-compiler/issues/202)

## 0.11
* New features:
  * `CLaSH.XException`: a module defining an exception representing uninitialised values. Additionally adds the `ShowX` class which has methods that prints values as "X" where they would normally raise an `XException` exception.
  * Add `BNat` (and supporting functions) to `CLaSH.Promoted.Nat`: base-2 encoded natural numbers.
  * Add `divSNat` and `logBaseSNat` to `CLaSH.Promoted.Nat`: division and logarithm for singleton natural numbers.
  * Add `predUNat` and `subUNat` to `CLaSH.Promoted.Nat`: predecessor and subtraction for unary-encoded natural numbers.
  * Add `dtfold` to `CLaSH.Sized.Vector`: a dependently-typed tree-fold over `Vec`.
  * Add the perfect-depth binary trees module `CLaSH.Sized.RTree`
  * Synthesisable definitions of `countLeadingZeros` and `countTrailingZeros` for: `BitVector`, `Signed`, `Unsigned`, and `Fixed`
  * Add the `(:::)` type alias in `CLaSH.NamedTypes` which allows you to annotate types with documentation
* Changes:
  * `asyncRam`, `blockRam`, `blockRamFile` have a `Maybe (addr,a)` as write input instead of three separate `Bool`, `addr`, and `a` inputs.
  * `asyncFIFOSynchronizer` has a `Maybe a` as write-request instead of a separate `Bool` and `a` input
  * `bundle'` and `unbundle'` are removed; `bundle` now has type `Unbundled' clk a -> Signal' clk a`, `unbundle` now has type `Signal' clk a -> Unbundled' clk a`
  * `subSNat` now has the type `SNat (a+b) -> SNat b -> SNat a` (where it used to be `SNat a -> SNat b -> SNat (a-b)`)
  * Renamed `multUNat` to `mulUNat` to be in sync with `mulSNat` and `mulBNat`.
  * The function argument of `vfold` in `CLaSH.Sized.Vector` is now `(forall l . SNat l -> a -> Vec l b -> Vec (l + 1) b)` (where it used to be `(forall l . a -> Vec l b -> Vec (l + 1) b)`)
  * `Cons` constructor of `Vec` is no longer visible; `(:>)` and `(:<)` are now listed as constructors of `Vec`
  * Simulation speed improvements for numeric types

## 0.10.12
* Fixes bugs:
  * `Vec`s `unbundle` is too strict, i.e. `register (undefined :: Vec 2 Int)` /= `bundle . unbundle . register (undefined :: Vec 2 Int)`

## 0.10.11 *August 3rd 2016*
* New features:
  * Add strict version of: `sample`, `sampleN`, `fromList`, and `simulate`
  * Make `Signal`s `<*>` slightly stricter:
    * Feedback loops still work with this new implementation
    * No more space-leaks when used in combination with the strict version of `sample`, `sampleN`, and `simulate`
  * Add `NFData` instances for the numeric types
* Speed up arithmetic operations of `Signed`, `Unsigned` and `BitVector`
* Fixes bugs:
  * CLaSH compiler sees internals of numeric types in their `Lift` functions

## 0.10.10 *July 15th 2016*
* Fixes bugs:
  * `shrink` functions for numeric types throw exceptions [#153](https://github.com/clash-lang/clash-compiler/issues/153)
  * CLaSH compiler sees internals of numeric types in their Show functions

## 0.10.9 *June 9th 2016*
* Fixes bugs:
  * `Eq` instance of `Vec` sometimes not synthesisable

## 0.10.8 *June 7th 2016*
* New features:
  * Instances of `Data` for numeric types.
  * Instances of `Read` for {Index, Signed, Unsigned, Fixed}
  * Instances of `BitPack` for 3-8 tuples

## 0.10.7 *April 7th 2016*
* Support doctest-0.11.0

## 0.10.6 *February 10th 2016*
* Fixes bugs:
  * `CLaSH.Prelude.DataFlow.parNDF` is not lazy enough

## 0.10.5 *January 13th 2016*
* New features:
  * Add `readNew` to `CLaSH.Prelude.BlockRam`: create a read-after-write blockRAM from a read-before-write blockRAM.
  * `popCount` functions for `BitVector`, `Signed`, and `Unsigned` are now synthesisable.
  * Add `parNDF` to `CLaSH.Prelude.DataFlow`: compose _N_ dataflow circuits in parallel.
  * Add and instance `Vec n a` for `LockStep` in `CLaSH.Prelude.DataFlow`: have _N_ dataflow circuits operate in lock-step.

## 0.10.4 *December 11th 2015*
* New features:
  * Add `pureDF` to `CLaSH.Prelude.DataFlow`: lift combinational circuits to `DataFlow` circuits.
  * Add `fifoDF` to `CLaSH.Prelude.DataFlow`: a simple FIFO buffer adhering to the `DataFlow` protocol.
  * `loopDF` no longer uses the `lockStep` and `stepLock` automatically, and now includes a FIFO buffer on the feedback path.
  * Add `loopDF_nobuf` to `CLaSH.Prelude.DataFlow`: a version of `loopDF` with no FIFO buffer on the feedback path.
  * Add `boolToBV` to `CLaSH.CLass.BitPack`: convert `Bool`eans to `n`-bit `BitVector`s.
  * `ClockSource` in `CLaSH.Annotations.TopEntity` can now have multiple clock inputs [#33](https://github.com/clash-lang/clash-prelude/issues/33)
* Bug fixes:
  * `asyncRomFile` reads file multiple times.

## 0.10.3 *October 24th 2015*
* Disable CPR analysis (See https://github.com/clash-lang/clash-compiler/commit/721fcfa9198925661cd836668705f817bddaae3c):
  * GHC < 7.11: In all modules using `-fcpr-off`
  * GHC >= 7.11: In `CLaSH.Signal.Internal` and `CLaSH.Prelude.RAM` using `-fno-cpr-anal`

## 0.10.2 *October 21st 2015*
* New features:
  * `ExtendingNum`, `BitPack`, and `Resize` instance for `Index`
  * Add `bv2i`: convert `BitVector n` to `Index (2^n)`
  * Export type-level operations from [ghc-typelits-extra](http://hackage.haskell.org/package/ghc-typelits-extra)

## 0.10.1 *October 16th 2015*
* New features:
  * The `f` in `dfold p f`, now has an `SNat l` instead of a `Proxy l` as its first argument.
  * Add `bv2v` and `v2bv` functions that convert between `Vec n Bit` and `BitVector n`.
  * Add `smap`: apply a function to every element of a vector and the element's position (as an 'SNat' value) in the vector.

## 0.10 *October 3rd 2015*
* New features:
  * The Vec constructor `:>` is now an explicitly bidirectional pattern synonym (the actual constructor has been renamed to Cons).
    As a result, pattern matching on `:>` is now synthesisable by the CLaSH compiler.
  * The function `<:` is replaced by the the explicitly bidirectional pattern synonym `:<`.
    This allows you to pattern match on: "all but the last element of a vector" and "the last element" of the vector.
    Because it is a bidirectional pattern, `:<` can also be used as an expression that appends an element to the tail of a vector.
  * Add a `transpose` function in `CLaSH.Sized.Vector`.
  * Add `stencil1d` and `stensil2d` stencil computation functions in `CLaSH.Sized.Vector`.
  * Add `permute`, `backpermute`, `scatter`, and `gather` permutation functions in `CLaSH.Sized.Vector`.
  * Add specialised permutation functions `interleave`, `rotateLeft`, and `rotateRight` in `CLaSH.Sized.Vector`.
  * `sscanl` and `sscanr` in `CLaSH.Sized.Vector` are renamed to `postscanl` and postscanr` to be more in line with existing Haskell packages such as `vector` and `accelerate`.
  * The `Foldable` and `Traversable` instances of `Vec` now only works for non-empty vectors.
  * Where possible, members of the `Foldable` instance of `Vec` are described in terms of `fold`, which builds a tree (of depth `log(n)`) of computations, instead of `foldr` which had depth `n` computations.
    This reduces the critical path length in your circuits when using these functions.
  * `maxIndex` and `length` in `CLaSH.Sized.Vector` return an `Int` instead of an `Integer`.
  * Add functions that involve an index into a vector to the `CLaSH.Sized.Vector` module: `indices`, `indicesI`, `imap`, `izipWith`, `ifoldr`, `ifoldl`, `findIndex`, `elemIndex`.
  * `CLaSH.Sized.Vector`'s `fold`, `dfold`, `vfold`, and `toList` are now synthesisable by the CLaSH compiler.

## 0.9.3 *September 21st 2015*
* Fixes bugs:
  * Cannot build against singletons-0.2
  * Numerous documentation fixes

## 0.9.2 *August 2nd 2015*
* Disable strictness analysis in `CLaSH.Signal.Internal`, this allows turning on strictness analysis in the GHC front-end of the CLaSH compiler.

## 0.9.1 *June 26th 2015*
* Updated documentation on data-file support on Altera/Quartus

## 0.9 *June 25th 2015*
* New features:
  * Add operations on singleton natural numbers: `addSNat`, `subSNat`, `mulSNat`, and `powSNat`.
  * Add asynchronous RAM functions in `CLaSH.Prelude.RAM`, which have an asynchronous/combinational read port.
  * Add ROM functions in modules `CLaSH.Prelude.ROM` and `CLaSH.Prelude.ROM.File`, where the latter module contains functions that instantiate a ROM from the content specified in an external data-file.
  * Add BlockRam functions, in the `CLaSH.Prelude.BlockRam.File` module, whose content can be initialised with the content specified in an external data-file.
  * `assert` now takes an extra `String` argument so you can distinguish one `assert` from the others.
  Additionally, `assert'` is added which takes an additional `SClock` argument.
  This is needed, because `assert` now reports the clock cycle, and clock domain, when an assertion fails.
  * `defClkAltera` and `defClkXilinx` are replaced by, `altpll` and `alteraPll` for Altera clock sources, and `clockWizard` for Xilinx clock sources.
  These names correspond to the names of the generator utilities in Quartus and ISE/Vivado.
  * Add [Safe](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/safe_haskell.html) versions of the prelude modules: `CLaSH.Prelude.Safe` and `CLaSH.Prelude.Explicit.Safe`
  * Add synchronizers in the `CLaSH.Prelude.Synchronizer` module

## 0.8 *June 3rd 2015*
* New features:
  * Make the (Bit)Vector argument the _last_ argument for the following functions: `slice`, `setSlice`, `replaceBit`, `replace`. The signatures for the above functions are now:

    ```
    slice      :: BitPack a => SNat m -> SNat n -> a -> BitVector (m + 1 - n)
    setSlice   :: BitPack a => SNat m -> SNat n -> BitVector (m + 1 - n) -> a -> a
    replaceBit :: Integral i => i -> Bit -> a -> a
    replace    :: Integral i => i -> a -> Vec n a -> Vec n a
    ```

    This allows for easier chaining, e.g.:

    ```
    replaceBit 0 1 $
    repleceBit 4 0 $
    replaceBit 6 1 bv
    ```
  * Until version 0.7.5, given `x :: Vec 8 Bit` and `y :: BitVector 8`, it used to be `last x == msb y`.
    This is quite confusing when printing converted values.
    Until version 0.7.5 we would get:

    ```
    > 0x0F :: BitVector 8
    0000_1111
    > unpack 0x0F :: Vec 8 Bit
    <1,1,1,1,0,0,0,0>
    ```

    As of version 0.8, we have `head x == msb y`:

    ```
    > 0x0F :: BitVector 8
    0000_1111
    > unpack 0x0F :: Vec 8 Bit
    <0,0,0,0,1,1,1,1>
    ```

    So converting for `Vec`tors of `Bit`s to `BitVector`s is no longer _index_-preserving, but it is _order_-preserving.
  * Add [QuickCheck](http://hackage.haskell.org/package/QuickCheck) `Arbitary` and `CoArbitary` instances for all data types
  * Add [lens](http://hackage.haskell.org/package/lens) `Ixed` instances for `BitVector`, `Signed`, `Unsigned`, and `Vec`

## 0.7.5 **May 7th 2015**
* New features:
  * Moore machine combinators

## 0.7.4 **May 5th 2015*
* New features:
  * Add `TopEntity` annotations

## 0.7.3 *April 22nd 2015*
* New features:
  * Add the vector functions: `zip3`, `unzip3`, and `zipWith3`
  * Use version 0.2 of the [`ghc-typelits-natnormalise` package](http://hackage.haskell.org/package/ghc-typelits-natnormalise)

## 0.7.2 *April 20th 2015*
* New features:
  * Support for GHC 7.10 => only works with GHC 7.10 and higher
  * Use http://hackage.haskell.org/package/ghc-typelits-natnormalise typechecker plugin for better type-level natural number handling

## 0.7.1 *March 25th 2015*
* Fixes bugs:
  * Fix laziness bug in Vector.(!!) and Vector.replace

## 0.7 *March 13th 2015*
* New features:
  * Switch types of `bundle` and `bundle'`, and `unbundle` and `unbundle'`.
  * Rename all explicitly clocked versions of Signal functions, to the primed
    name of the implicitly clocked Signal functions. E.g. `cregister` is now
    called `register'` (where the implicitly clocked function is callled `register`)
  * Add new instances for `DSignal`
  * Add experimental `antiDelay` function for `DSignal`
  * Generalize lifted functions over Signals (e.g. (.==.))

* Fixes bugs:
  * Faster versions of Vector.(!!) and Vector.replace

## 0.6.0.1 *November 17th 2014*
* Fixes bugs:
  * Add missing 'CLaSH.Sized.BitVector' module to .cabal file.

## 0.6 *November 17th 2014*

* New features:
  * Add `Fractional` instance for `Fixed` [#9](https://github.com/christiaanb/clash-prelude/issues/9)
  * Make indexing/subscript of `Vec` ascending [#4](https://github.com/christiaanb/clash-prelude/issues/4)
  * Add separate `BitVector` type, which has a descending index.
  * Add bit indexing operators, including the index/subscript operator `(!)`.
  * Add bit reduction operators: `reduceOr`, `reduceAnd`, `reduceOr`.
  * Rename `BitVector` class to `BitPack` with `pack` and `unpack` class methods.
  * Rename `Pack` class to `Bundle` with `bundle` and `unbundle` class methods.
  * Strip all `Vec` functions from their `v` prefix, i.e. `vmap` -> `map`.
  * Rename `Vec` indexing operator from `(!)` to `(!!)`.
  * Combine `Add` and `Mult` class into `ExtendingNum` class.
  * Add extend and truncate methods to the `Resize` class.
  * Add `SaturatingNum` class with saturating numeric operators.
  * Add multitude of lifted `Signal` operators, i.e. `(.==.) :: Eq a => Signal a -> Signal a -> Signal Bool`
  * Add `CLaSH.Signal.Delayed` with functions and data types for delay-annotated signals to support safe synchronisation.
  * Add `CLASH.Prelude.DataFlow` with functions and data types to create self-synchronising circuits based on data-flow principles.

* Fixes bugs:
  * Remove deprecated 'Arrow' instance for and related functions for `Comp` [#5](https://github.com/christiaanb/clash-prelude/issues/5)

## 0.5.1 *June 5th 2014*

* New features:
  * Add `Default` instance for `Vec` [#2](https://github.com/christiaanb/clash-prelude/issues/2)
  * Instantiation for `blockRam` [#3](https://github.com/christiaanb/clash-prelude/issues/2)

* Fixes bugs:
  * Fixed error on documentation of fLit in Fixed.hs [#6](https://github.com/christiaanb/clash-prelude/issues/6)
  * Non-translatable `Enum` function interfere with `sassert` compilation [#7](https://github.com/christiaanb/clash-prelude/issues/7)
  * Substituted the word 'list' into 'vector' in some places in the documentation. [#8](https://github.com/christiaanb/clash-prelude/issues/8)
  * mark vselectI INLINEABLE [#10](https://github.com/christiaanb/clash-prelude/issues/10)

## 0.5 *April 3rd 2014*
  * Add explicitly clocked synchronous signals for multi-clock circuits

## 0.4.1 *March 27th 2014*
  * Add saturation to fixed-point operators
  * Finalize most documentation

## 0.4 *March 20th 2014*
  * Add fixed-point integers
  * Extend documentation
  * 'bit' and 'testBit' functions give run-time errors on out-of-bound positions

## 0.3 *March 14th 2014*
  * Add Documentation
  * Easy SNat literals for 0..1024, e.g. d4 = snat :: SNat 4
  * Fix blockRamPow2

## 0.2 *March 5th 2014*
  * Initial release
