{-# OPTIONS_GHC -F -pgmF htfpp #-}
module TestFetcherArpansa where

import Codec.Picture

import qualified Data.ByteString as BS
import Data.Time.Calendar
import Data.Time.LocalTime

import Data
import Fetcher.Arpansa

import Test.Framework


testImage :: IO DynamicImage
testImage = do
    bytes <- BS.readFile "test/mel_rt.gif"
    let (Right image) = decodeImage bytes
    return image

test_selectForecastLine = do
    img <- testImage
    let graphLine = selectForecastLine img
    assertBool $ (274, 337) `elem` graphLine
    assertBool $ not $ (272, 336) `elem` graphLine
    assertBool $ not $ (755, 308) `elem` graphLine
    assertBool $ not $ (215, 541) `elem` graphLine

test_extrapolate = do
    let extrapolateExample = extrapolate (0, 10) (1, 20)
    assertEqual 10 $ extrapolateExample 0
    assertEqual 20 $ extrapolateExample 1
    assertEqual 30 $ extrapolateExample 2

test_graphLevel = do
    assertEqual (UVLevel 10) (graphLevel 231)
    assertEqual (UVLevel 5) (graphLevel 336)

test_graphTimeOfDay = do
        assertEqual (TimeOfDay 11 0 0) $ roundTime $ graphTimeOfDay 312
        assertEqual (TimeOfDay 17 0 0) $ roundTime $ graphTimeOfDay 586
    where roundTime (TimeOfDay h m _) = TimeOfDay h m 0

test_parseGraph = do
        img <- testImage
        let fc = parseGraph "Melbourne" day img
        assertEqual "Melbourne" (city $ location fc)
        assertEqual day (date fc)
        assertEqual (UVLevel 10) (maxLevel fc)
        let fcStart = alertStart fc
        let fcEnd = alertEnd fc
        assertBool (fcStart > (TimeOfDay 9 0 0) && fcStart < (TimeOfDay 9 30 0))
        assertBool (fcEnd > (TimeOfDay 17 40 0) && fcEnd < (TimeOfDay 18 0 0))
    where Just day = fromGregorianValid 2016 1 19