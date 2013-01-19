{-# LANGUAGE TypeOperators, Arrows #-}
{- |
The `ArrowList' type class, and a collection of list arrow related functions.
This typeclass can be used to embed functions producing multiple outputs into a
an arrow.
-}
module Control.Arrow.ArrowList
(
  -- * ArrowList type class.
  ArrowList (..)

  -- * Creating list arrows.
, unlist
, unite
, none
, concatA

  -- * Collecting the results.
, list
, empty

  -- * Conditional and filter arrows.
, isA
, ifA
, when
, guards
, filterA
, notA
, orElse

  -- * Optionality.
, maybeL
, optional
)
where

import Control.Monad hiding (when)
import Control.Category
import Control.Arrow
import Prelude hiding ((.), id)

-- | The `ArrowList' class represents two possible actions:
-- 
--   1. Lifting functions from one value to a list of values into a list arrow.
-- 
--   2. Mapping a function over the result list of a list arrow.

class Arrow ar => ArrowList ar where
  arrL :: (a -> [b]) -> a `ar` b
  mapL :: ([b] -> [c]) -> (a `ar` b) -> (a `ar` c)

-- | Create a list arrow of an input list.

unlist :: ArrowList ar => [b] `ar` b
unlist = arrL id

-- | Take the output of an arrow producing two results and concatenate them
-- into the result of the list arrow.

unite :: ArrowList ar => (a `ar` (b, b)) -> a `ar` b
unite = mapL (concatMap (\(a, b) -> [a, b]))

-- | Ignore the input and produce no results. Like `zeroArrow'.

none :: ArrowList ar => a `ar` b
none = arrL (const [])

-- | Collect the results of applying multiple arrows to the same input.

concatA :: ArrowPlus ar => [a `ar` b] -> a `ar` b
concatA = foldr (<+>) zeroArrow

-- | Collect the entire results of an list arrow as a singleton value in the
-- result list.

list :: ArrowList ar => (a `ar` b) -> a `ar` [b]
list = mapL return

-- | Returns a `Bool' indicating whether the input arrow produce any results.

empty :: ArrowList ar => (a `ar` b) -> a `ar` Bool
empty = mapL (\xs -> [if null xs then True else False])

-- | Create a filtering list arrow by mapping a predicate function over the
-- input. When the predicate returns `True' the input will be returned in the
-- output list, when `False' the empty list is returned.

isA :: ArrowList ar => (a -> Bool) -> a `ar` a
isA f = arrL (\a -> if f a then [a] else [])

-- | Use the result a list arrow as a conditional, like an if-then-else arrow.
-- When the first arrow produces any results the /then/ arrow will be used,
-- when the first arrow produces no results the /else/ arrow will be used.

ifA :: (ArrowList ar, ArrowChoice ar)
    => (a `ar` c)  -- ^ Arrow used as condition.
    -> (a `ar` b)  -- ^ Arrow to use when condition has results.
    -> (a `ar` b)  -- ^ Arrow to use when condition has no results.
    -> a `ar` b
ifA c t e = proc i -> do x <- empty c -< i; if x then e -< i else t -< i

-- | Apply a list arrow only when a conditional arrow produces any results.
-- When the conditional produces no results the output arrow /behaves like the identity/.
-- The /second/ input arrow is used as the conditional, this allow
-- you to write: @ a \`when\` c @

infix 8 `when`

when :: (ArrowList ar, ArrowChoice ar)
     => (a `ar` a)  -- ^ The arrow to apply,
     -> (a `ar` b)  -- ^ when this conditional holds.
     -> a `ar` a
when a c = ifA c a id

-- | Apply a list arrow only when a conditional arrow produces any results.
-- When the conditional produces no results the output arrow /produces no results/.
-- The /first/ input arrow is used as the conditional, this allow you
-- to write: @ c \`guards\` a @

infix 8 `guards`

guards :: (ArrowList ar, ArrowChoice ar)
       => (a `ar` c)  -- ^ When this condition holds,
       -> (a `ar` b)  -- ^ then apply this arrow.
       -> a `ar` b
guards c a = ifA c a none

-- | Filter the results of an arrow with a predicate arrow, when the filter
-- condition produces results the input is accepted otherwise it is excluded.

filterA :: (ArrowChoice ar, ArrowList ar) => (a `ar` c) -> a `ar` a
filterA c = ifA c id none

-- | Negation list arrow. Only accept the input when the condition produces no
-- output.

notA :: (ArrowList ar, ArrowChoice ar) => (a `ar` c) -> a `ar` a
notA c = ifA c none id

-- | Apply the input arrow, when the arrow does not produces any results the
-- second fallback arrow is applied.
-- Likely written infix like this @ a \`orElse\` b @

infix 8 `orElse`

orElse :: (ArrowList ar, ArrowChoice ar) => (a `ar` b) -> (a `ar` b) -> a `ar` b
orElse a = ifA a a 

-- | Map a `Maybe' input to a list output. When the Maybe is a `Nothing' an
-- empty list will be returned, `Just' will result in a singleton list.

maybeL :: ArrowList ar => Maybe a `ar` a
maybeL = arrL (maybe [] return)

-- | Apply a list arrow, when there are no results a `Nothing' will be
-- returned, otherwise the results will be wrapped in a `Just'. This function
-- always produces result.

optional :: (ArrowChoice ar, ArrowList ar) => (a `ar` b) -> a `ar` Maybe b
optional a = ifA a (arr Just . a) (arr (const Nothing))

