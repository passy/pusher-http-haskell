{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TupleSections #-}

{-|
Module      : Network.Pusher.Protocol
Description : Types representing Pusher messages
Copyright   : (c) Will Sewell, 2015
Licence     : MIT
Maintainer  : me@willsewell.com
Stability   : experimental

Types representing the JSON format of Pusher messages.

There are also types for query string parameters.
-}
module Network.Pusher.Protocol
  ( Channel(..)
  , ChannelInfo(..)
  , ChannelInfoAttributes(..)
  , ChannelInfoQuery(..)
  , ChannelsInfo(..)
  , ChannelsInfoQuery(..)
  , ChannelsInfoAttributes(..)
  , ChannelType(..)
  , Users
  , toURLParam
  ) where

import Control.Applicative ((<$>))
import Data.Aeson ((.:), (.:?))
import Data.Foldable (asum)
import Data.Hashable (Hashable, hashWithSalt)
import Data.Maybe (fromMaybe)
import GHC.Generics (Generic)
import qualified Data.Aeson as A
import qualified Data.HashMap.Strict as HM
import qualified Data.HashSet as HS
import qualified Data.Text as T

import Network.Pusher.Internal.Util (failExpectObj, show')

-- |The possible types of Pusher channe.
data ChannelType = Public | Private | Presence deriving (Eq, Generic)

instance Hashable ChannelType

instance Show ChannelType where
  show Public = ""
  show Private = "private-"
  show Presence = "presence-"

-- |The channel name (not including the channel type prefix) and its type.
data Channel = Channel
  { channelType :: ChannelType
  , channelName :: T.Text
  } deriving (Eq, Generic)

instance Hashable Channel

instance Show Channel where
  show (Channel chanType name) = show chanType ++ show name

-- |Convert string representation, e.g. private-chan into the datatype
parseChannel :: T.Text -> Channel
parseChannel chan =
  -- Attempt to parse it as a private or presence channel; default to public
  fromMaybe
    (Channel Public chan)
    (asum [parseChanAs Private,  parseChanAs Presence])
 where
  parseChanAs chanType =
    let split = T.splitOn (show' chanType) chan in
    -- If the prefix appears at the start, then the first element will be empty
    if length split > 1 && T.null (head split) then
      Just $ Channel chanType (T.concat $ tail split)
    else
      Nothing

-- |Types that can be serialised to a querystring parameter value.
class ToURLParam a where
  -- |Convert the data into a querystring parameter value.
  toURLParam :: a -> T.Text

-- |Enumeration of the attributes that can be queried about multiple channels.
data ChannelsInfoAttributes = ChannelsUserCount deriving Generic

instance ToURLParam ChannelsInfoAttributes where
  toURLParam ChannelsUserCount = "user_count"

instance Hashable ChannelsInfoAttributes

-- |A set of requested ChannelsInfoAttributes.
newtype ChannelsInfoQuery =
  ChannelsInfoQuery (HS.HashSet ChannelsInfoAttributes)
  deriving ToURLParam

-- |Enumeration of the attributes that can be queried about a single channel.
data ChannelInfoAttributes = ChannelUserCount | ChannelSubscriptionCount
  deriving Generic

instance ToURLParam ChannelInfoAttributes where
  toURLParam ChannelUserCount = "user_count"
  toURLParam ChannelSubscriptionCount = "subscription_count"

instance Hashable ChannelInfoAttributes

-- |A set of requested ChannelInfoAttributes.
newtype ChannelInfoQuery = ChannelInfoQuery (HS.HashSet ChannelInfoAttributes)
  deriving ToURLParam


instance ToURLParam a => ToURLParam (HS.HashSet a) where
  toURLParam hs = T.concat $ toURLParam <$> HS.toList hs

-- |A map of channels to their ChannelInfo. The result of querying channel
-- info from multuple channels.
newtype ChannelsInfo =
  ChannelsInfo (HM.HashMap Channel ChannelInfo)
  deriving Show

instance A.FromJSON ChannelsInfo where
  parseJSON (A.Object v) = do
    chansV <- v .: "channels"
    case chansV of
      A.Object cs ->
        -- Need to go to and from list in order to map (parse) the keys
        ChannelsInfo . HM.fromList
          <$> mapM
            (\(channel, info) -> (parseChannel channel,) <$> A.parseJSON info)
            (HM.toList cs)
      v1 -> failExpectObj v1
  parseJSON v2 = failExpectObj v2

-- |A set of returned channel attributes for a single channel.
newtype ChannelInfo =
  ChannelInfo (HS.HashSet ChannelInfoAttributeResp)
  deriving Show

instance A.FromJSON ChannelInfo where
  parseJSON (A.Object v) = do
    maybeUserCount <- v .:? "user_count"
    return $ ChannelInfo $ maybe
      HS.empty
      (HS.singleton . UserCountResp)
      maybeUserCount
  parseJSON v = failExpectObj v

-- |An enumeration of possible returned channel attributes. These now have
-- associated values.
data ChannelInfoAttributeResp = UserCountResp Int deriving Show

instance Hashable ChannelInfoAttributeResp where
  hashWithSalt salt (UserCountResp count) = hashWithSalt salt count

-- |A list of users returned by querying for users in a presence channel.
newtype Users = Users [User] deriving Show

instance A.FromJSON Users where
  parseJSON (A.Object v) = do
    users <- v .: "users"
    Users <$> A.parseJSON users
  parseJSON v = failExpectObj v

-- |The data about a user returned when querying for users in a presence channel.
data User = User { userID :: T.Text } deriving Show

instance A.FromJSON User where
  parseJSON (A.Object v) = User <$> v .: "id"
  parseJSON v = failExpectObj v
