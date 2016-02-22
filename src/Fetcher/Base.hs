module Fetcher.Base where

{- Base functions for all the UV level sources -}

import Network.URI

import App
import Types
import Types.Location


data Fetcher = Fetcher { fName :: String
                       , fFetch :: AppM [Forecast]
                       }

logError :: (Monoid a, Show c) => c -> IOError -> AppM a
logError context err = do
    logStr $ "Error fetching " ++ show context ++ ": " ++ show err
    return mempty
