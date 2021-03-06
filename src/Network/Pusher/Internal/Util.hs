{-|
Module      : Network.Pusher.Internal.Util
Description : Various utilty functions
Copyright   : (c) Will Sewell, 2015
Licence     : MIT
Maintainer  : me@willsewell.com
Stability   : experimental
-}
module Network.Pusher.Internal.Util
  ( failExpectObj
  , show'
  ) where

import Control.Applicative ((<$>))
import Data.String (IsString, fromString)
import qualified Data.Aeson as A
import qualified Data.Aeson.Types as A

-- |When decoding Aeson values, this can be used to return a failing parser
-- when an object was expected, but it was a different type of data.
failExpectObj :: A.Value -> A.Parser a
failExpectObj = fail . ("Expected JSON object, got " ++) . show

-- | Generalised version of show
show' :: (Show a, IsString b) => a -> b
show' = fromString . show
