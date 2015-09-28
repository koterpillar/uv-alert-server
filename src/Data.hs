{-# Language DeriveGeneric #-}
{-# Language OverloadedStrings #-}
module Data where

import Control.Monad

import Data.Aeson
import qualified Data.Map as M
import qualified Data.Text as T

import GHC.Generics

import Servant


trim :: String -> String
trim = trimStart . trimEnd
    where trimStart = dropWhile (== ' ')
          trimEnd = reverse . trimStart . reverse

stringPart :: Int -> Int -> String -> String
stringPart start len = take len . drop start

stringPartT :: Int -> Int -> String -> String
stringPartT start len = trim . stringPart start len

readEither :: Read a => e -> String -> Either e a
readEither err str = case reads str of
    [(res, "")] -> Right res
    _ -> Left err

-- Supplementary types
-- TODO: change them to something nicer

data Location = Location { city :: String
                         }
    deriving (Eq, Show, Generic)

instance FromText Location where
    fromText txt = Location <$> fromText txt

instance ToJSON Location

data Date = Date { year :: Int
                 , month :: Int
                 , day :: Int
                 }
    deriving (Eq, Show, Generic)

instance ToJSON Date

parseDate :: String -> Either String Date
parseDate str = do
    day <- readEither "day" $ stringPartT 0 2 str
    month <- readEither "month" $ stringPartT 3 2 str
    year <- readEither "year" $ stringPartT 6 4 str
    return $ Date year month day

data Time = Time { hour :: Int
                 , minute :: Int
                 }
    deriving (Eq, Show, Generic)

instance ToJSON Time

parseTime :: String -> Either String Time
parseTime str = do
    hour <- readEither "hour" $ stringPartT 0 2 str
    minute <- readEither "minute" $ stringPartT 3 2 str
    return $ Time hour minute

data UVLevel = UVLevel Int
    deriving (Eq, Show, Generic)

instance ToJSON UVLevel

{-
          10        20        30        40        50        60        70       80
          *         *         *         *         *         *         *        *
Index BoM    WMO  Location            DayMonYear  UV Alert period (local time)  UVI max
0009 070014 94926 Canberra            26 09 2015  UV Alert from  8.50 to 15.00  Max:  7
-}
data Forecast = Forecast { location :: Location
                         , date :: Date
                         , alertStart :: Time
                         , alertEnd :: Time
                         , maxLevel :: UVLevel
                         }
    deriving (Eq, Show, Generic)

instance ToJSON Forecast

-- TODO: Parsec
parseForecast :: String -> Either String Forecast
parseForecast str = do
    let location = Location $ stringPartT 18 20 str
    date <- parseDate $ stringPart 38 10 str
    tStart <- parseTime $ stringPart 64 5 str
    tEnd <- parseTime $ stringPart 73 5 str
    max <- liftM UVLevel $ readEither "UV level" $ stringPartT 84 3 str
    return $ Forecast location date tStart tEnd max

data AppKey = AppKey { key :: String }

instance FromFormUrlEncoded AppKey where
    fromFormUrlEncoded = liftM (AppKey . T.unpack) . maybeToEither "key not found" . M.lookup "key" . M.fromList
        where maybeToEither _ (Just x) = Right x
              maybeToEither err Nothing = Left err
