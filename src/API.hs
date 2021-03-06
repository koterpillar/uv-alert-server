{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}

module API
  ( API
  , api
  ) where

import Servant

import Types
import Types.Location

type RegisterAppAPI
   = "register-app" :> ReqBody '[ FormUrlEncoded] AppKey :> Post '[ JSON] ()

type ForecastAPI
   = "forecast" :> Capture "location" Location :> Get '[ JSON] [Forecast]

type LocationsAPI = "locations" :> Get '[ JSON] [LocationCoordinates]

type API = RegisterAppAPI :<|> ForecastAPI :<|> LocationsAPI

api :: Proxy API
api = Proxy
