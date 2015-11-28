module Fetcher where

import Control.Concurrent

import Control.Exception.Lifted

import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.State
import Control.Monad.Trans.Reader

import Data.Either
import qualified Data.Set as S
import Data.Time.Clock

import Network.FTP.Client
import Network.URI

import App
import Data
import Pusher


updateInterval :: Int -- microseconds
updateInterval = 3600 * 1000000

-- Data for today
todayAddress :: URI
Just todayAddress = parseURI "ftp://ftp2.bom.gov.au/anon/gen/fwo/IDYGP007.txt"

-- Data for tomorrow (forecast)
forecastAddress :: URI
Just forecastAddress = parseURI "ftp://ftp2.bom.gov.au/anon/gen/fwo/IDYGP026.txt"


runFetcher :: Config -> IO ()
runFetcher = runReaderT fetcher

fetcher :: AppM ()
fetcher = forever $ do
    fetch
    removeOld
    liftIO $ threadDelay updateInterval

fetch :: AppM ()
fetch = do
    forM_ [todayAddress, forecastAddress] $ \address -> do
        logStr $ "Fetching " ++ show address ++ "..."
        handle (logError address) $ do
            content <- fetchLines address
            let newForecasts = rights $ map parseForecast $ lines content
            logStr $ "Added " ++ show (length newForecasts) ++ " forecasts."
            stateM $ modify $
                \store -> store { forecasts = S.fromList newForecasts `S.union` forecasts store }
    push
    where
        logError :: URI -> IOError -> AppM ()
        logError address err = logStr $ "Error fetching " ++ show address ++ ": " ++ show err

fetchLines :: MonadIO m => URI -> m String
fetchLines uri = liftIO $ do
    let (Just host) = liftM uriRegName $ uriAuthority uri
    conn <- easyConnectFTP host
    loginAnon conn
    (content, _) <- getbinary conn $ uriPath uri
    return content

fetchTestContent :: MonadIO m => m String
fetchTestContent = liftIO $ readFile "src/IDYGP007.txt"

removeOld :: AppM ()
removeOld = do
    oldCount <- stateM $ gets (length . forecasts)
    now <- liftIO getCurrentTime
    stateM $ modify $
        \store -> store { forecasts = S.filter (isRecent now) $ forecasts store }
    newCount <- stateM $ gets (length . forecasts)
    logStr $ "Removed " ++ show (oldCount - newCount) ++ " forecasts, " ++
        show newCount ++ " remain."
