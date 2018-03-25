module Data.Incremental.Record where

import Prelude

import Data.Incremental (class Patch, Jet, fromChange, patch, toChange)
import Data.Monoid (class Monoid, mempty)
import Data.Newtype (class Newtype, unwrap)
import Data.Record as Record
import Data.Symbol (class IsSymbol, SProxy(..))
import Type.Row (class RowLacks, class RowToList, Cons, Nil, RLProxy(..), kind RowList)

newtype WrappedRecord r = WrappedRecord (Record r)

derive instance newtypeWrappedRecord :: Newtype (WrappedRecord a) _

instance semigroupRecord
    :: (RowToList r rl, SemigroupRL rl r)
    => Semigroup (WrappedRecord r) where
  append (WrappedRecord x) (WrappedRecord y) = WrappedRecord (appendRL (RLProxy :: RLProxy rl) x y)

class SemigroupRL (rl :: RowList) r | rl -> r where
  appendRL :: RLProxy rl -> Record r -> Record r -> Record r

instance semigroupRLNil :: SemigroupRL Nil () where
  appendRL _ _ _ = {}

instance semigroupRLCons
    :: ( IsSymbol l
       , Semigroup a
       , SemigroupRL rl r1
       , RowCons l a r1 r2
       , RowLacks l r1
       , RowLacks l r2
       )
    => SemigroupRL (Cons l a rl) r2 where
  appendRL _ x y =
      Record.insert l
        (append (Record.get l x) (Record.get l y))
        rest
    where
      l = SProxy :: SProxy l

      rest :: Record r1
      rest = appendRL (RLProxy :: RLProxy rl) (Record.delete l x) (Record.delete l y)

instance monoidRecord
    :: (RowToList r rl, MonoidRL rl r)
    => Monoid (WrappedRecord r) where
  mempty = WrappedRecord (memptyRL (RLProxy :: RLProxy rl))

class SemigroupRL rl r <= MonoidRL (rl :: RowList) r | rl -> r where
  memptyRL :: RLProxy rl -> Record r

instance monoidRLNil :: MonoidRL Nil () where
  memptyRL _ = {}

instance monoidRLCons
    :: ( IsSymbol l
       , Monoid a
       , MonoidRL rl r1
       , RowCons l a r1 r2
       , RowLacks l r1
       , RowLacks l r2
       )
    => MonoidRL (Cons l a rl) r2 where
  memptyRL _ =
      Record.insert l mempty rest
    where
      l = SProxy :: SProxy l

      rest :: Record r1
      rest = memptyRL (RLProxy :: RLProxy rl)

instance patchRecord
    :: (RowToList r rl, RowToList d dl, MonoidRL dl d, PatchRL r rl d dl)
    => Patch (WrappedRecord r) (WrappedRecord d) where
  patch (WrappedRecord r) (WrappedRecord d) = WrappedRecord (patchRL (RLProxy :: RLProxy rl) (RLProxy :: RLProxy dl) r d)

class MonoidRL dl d <= PatchRL r (rl :: RowList) d (dl :: RowList) | rl -> r, dl -> d, rl -> dl where
  patchRL :: RLProxy rl -> RLProxy dl -> Record r -> Record d -> Record r

instance patchRLNil :: PatchRL () Nil () Nil where
  patchRL _ _ _ _ = {}

instance patchRLCons
    :: ( IsSymbol l
       , Patch a m
       , PatchRL r1 rl d1 dl
       , RowCons l a r1 r2
       , RowCons l m d1 d2
       , RowLacks l r1
       , RowLacks l r2
       , RowLacks l d1
       , RowLacks l d2
       )
    => PatchRL r2 (Cons l a rl) d2 (Cons l m dl) where
  patchRL _ _ x y =
      Record.insert l
        (patch (Record.get l x) (Record.get l y))
        rest
    where
      l = SProxy :: SProxy l

      rest :: Record r1
      rest = patchRL (RLProxy :: RLProxy rl) (RLProxy :: RLProxy dl) (Record.delete l x) (Record.delete l y)

-- | An incremental property accessor function
get
  :: forall l a da r rl rest1 rest2 d dl
   . IsSymbol l
  => RowCons l a rest1 r
  => RowCons l da rest2 d
  => RowToList r rl
  => RowToList d dl
  => PatchRL r rl d dl
  => Patch a da
  => SProxy l
  -> Jet (WrappedRecord r)
  -> Jet a
get l { position, velocity } =
  { position: Record.get l (unwrap position)
  , velocity: toChange (Record.get l (unwrap (fromChange velocity)))
  }