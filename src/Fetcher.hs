module Fetcher where

import Control.Concurrent

import Control.Exception.Lifted

import Control.Lens

import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.State
import Control.Monad.Trans.Reader

import Data.Either
import Data.List
import qualified Data.Set as S
import Data.Time.Clock

import GHC.Exts (groupWith)

import Network.FTP.Client
import Network.URI

import App
import Data
import Fetcher.Arpansa
import Fetcher.Base
import Pusher


updateInterval :: Int -- microseconds
updateInterval = 3600 * 1000000

fetchers :: [Fetcher]
fetchers = [arpansaFetcher]

runFetcher :: Config -> IO ()
runFetcher = runReaderT fetcher

fetcher :: AppM ()
fetcher = forever $ do
    fetchAll fetchers
    removeOldM
    liftIO $ threadDelay updateInterval

fetchAll :: [Fetcher] -> AppM ()
fetchAll fs = do
    forM_ fs $ \f -> do
        logStr $ "Fetching from " ++ fName f ++ "..."
        newForecasts <- fFetch f
        logStr $ "Added " ++ show (length newForecasts) ++ " forecasts."
        stateM $ modify $
            \store -> store { forecasts = S.fromList newForecasts `S.union` forecasts store }
    push

removeOldM :: AppM ()
removeOldM = do
    oldCount <- stateM $ gets (length . forecasts)
    now <- liftIO getCurrentTime
    stateM $ modify $
        \store -> store { forecasts = removeOld now (forecasts store) }
    newCount <- stateM $ gets (length . forecasts)
    logStr $ "Removed " ++ show (oldCount - newCount) ++ " forecasts, " ++
        show newCount ++ " remain."

removeOld :: UTCTime -> S.Set Forecast -> S.Set Forecast
removeOld now = S.fromList . filterBestEachDay . filter (isRecent now) . S.toList

-- Leave only the latest forecast for each day
filterBestEachDay :: [Forecast] -> [Forecast]
filterBestEachDay = map (maximumBy compareUpdated) . groupWith forecastKey
    where forecastKey fc = (fc ^. fcLocation, fc ^. fcDate)
