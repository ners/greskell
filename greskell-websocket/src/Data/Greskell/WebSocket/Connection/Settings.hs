-- |
-- Module: Data.Greskell.WebSocket.Connection.Settings
-- Description: Settings for making Connection
-- Maintainer: Toshio Ito <debug.ito@gmail.com>
--
-- 
module Data.Greskell.WebSocket.Connection.Settings
  ( -- * Settings
    Settings,
    defSettings,
    defJSONSettings,
    -- ** accessor functions
    codec, endpointPath, onGeneralException, responseTimeout, requestQueueSize
  ) where

import Data.Aeson (FromJSON)

import Data.Greskell.WebSocket.Codec (Codec)
import Data.Greskell.WebSocket.Codec.JSON (jsonCodec)
import Data.Greskell.WebSocket.Connection.Type (Connection, GeneralException)

import System.IO (stderr, hPutStrLn)

-- | 'Settings' for making connection to Gremlin Server.
--
-- You can get the default 'Settings' by 'defSettings' function, and
-- customize the fields by accessor functions.
data Settings s =
  Settings
  { codec :: !(Codec s),
    -- ^ codec for the connection
    endpointPath :: !String,
    -- ^ Path of the WebSocket endpoint. Default: \"/gremlin\"
    onGeneralException :: !(GeneralException -> IO ()),
    -- ^ An exception handler for 'GeneralException'. You don't have
    -- to re-throw the exception. Default: print the exception to
    -- stderr.
    responseTimeout :: !Int,
    -- ^ Time out (in seconds) for responses. It is the maximum time
    -- for which the connection waits for a response to complete after
    -- it sends a request. If the response consists of more than one
    -- ResponseMessages, the timeout applies to the last of the
    -- ResponseMessages. Default: 60
    requestQueueSize :: !Int
    -- ^ Size of the internal queue of requests. Usually you don't
    -- need to customize the field. Default: 8.
  }

defSettings :: Codec s -> Settings s
defSettings c = Settings
                { codec = c,
                  endpointPath = "/gremlin",
                  onGeneralException = \e -> hPutStrLn stderr $ show e,
                  responseTimeout = 60,
                  requestQueueSize = 8
                }

-- | 'defSettings' with 'jsonCodec'.
defJSONSettings :: FromJSON s => Settings s
defJSONSettings = defSettings jsonCodec