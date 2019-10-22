{-# LANGUAGE OverloadedStrings #-}
module Main (main,spec) where

import qualified Data.Vector as V
import qualified Network.Greskell.WebSocket.Client as WS
import System.IO (hPutStrLn, stderr)
import Test.Hspec

import Control.Category ((<<<))
import Control.Monad (void)
import Data.Text (Text)
import Data.Greskell.Binder (newBind, runBinder)
import Data.Greskell.Graph
  ( AVertex, Key, AEdge
  )
import Data.Greskell.GTraversal
  ( Walk, GTraversal, SideEffect,
    source, sV', sE', sAddV', gProperty, gId, gValues, gHasId, gHasLabel, gHas2,
    ($.), liftWalk,
    gAddE', gTo, gV'
  )

import ServerTest.Common (withEnv, withClient)

main :: IO ()
main = hspec spec

spec :: Spec
spec = withEnv $ do
  spec_values_type
  spec_generic_element_ID

clearGraph :: WS.Client -> IO ()
clearGraph client = WS.drainResults =<< WS.submitRaw client "g.V().drop()" Nothing

spec_values_type :: SpecWith (String,Int)
spec_values_type = describe "return type of .values step" $ do
  specify "input Int, get Int" $ withClient $ \client -> do
    let prop_key :: Key AVertex Int
        prop_key = "foobar"
        searchProp = WS.drainResults =<< WS.submit client script (Just binding)
          where
            (script, binding) = runBinder $ do
              input <- newBind (100 :: Int)
              return $ gHas2 prop_key input $. sV' [] $ source "g"
        putProp = WS.slurpResults =<< WS.submit client script (Just binding)
          where
            (script, binding) = runBinder $ do
              input <- newBind (100 :: Int)
              return $ liftWalk gId $. gProperty prop_key input $. sAddV' "hoge" $ source "g"
        getProp vid = WS.slurpResults =<< WS.submit client script (Just binding)
          where
            (script, binding) = runBinder $ do
              vid_var <- newBind vid
              return $ gValues [prop_key] $. gHasId vid_var $. gHasLabel "hoge" $. sV' [] $ source "g"
    clearGraph client
    searchProp
    got_ids <- putProp
    got <- getProp (got_ids V.! 0)
    V.toList got `shouldBe` [100]

spec_generic_element_ID :: SpecWith (String, Int)
spec_generic_element_ID = do
  specify "get Vertex ID as GValue, query Vertex by GValue" $ withClient $ \client -> do
    let prop_key :: Key AVertex Int
        prop_key = "sample"
        prop_val = 125
        make_v = liftWalk gId $. gProperty prop_key prop_val $. (sAddV' "test" $ source "g")
    clearGraph client
    got_ids <- fmap V.toList $ WS.slurpResults =<< WS.submit client make_v Nothing
    hPutStrLn stderr ("Got Vertex IDs: " <> show got_ids)
    length got_ids `shouldBe` 1
    let (q, qbind) = runBinder $ do
          vid <- newBind (got_ids !! 0)
          return $ gValues [prop_key] $. (sV' [vid] $ source "g")
    got_vals <- fmap V.toList $ WS.slurpResults =<< WS.submit client q (Just qbind)
    got_vals `shouldBe` [125]
  specify "get Edge ID as GValue, query Edge by GValue" $ withClient $ \client -> do
    let vname_key :: Key AVertex Text
        vname_key = "name"
        ename_key :: Key AEdge Text
        ename_key = "name"
        makeV n = (liftWalk $ gProperty vname_key n) $. (sAddV' "test_v" $ source "g")
        makeE fn tn = liftWalk gId
                      $. gProperty ename_key "e_test"
                      $. gAddE' "test_e" (gTo $ gHas2 vname_key tn <<< gV' [])
                      $. gHas2 vname_key fn
                      $. (liftWalk $ sV' [] $ source "g")
    clearGraph client
    void $ WS.slurpResults =<< WS.submit client (makeV "v_from") Nothing
    void $ WS.slurpResults =<< WS.submit client (makeV "v_to") Nothing
    got_ids <- fmap V.toList $ WS.slurpResults =<< WS.submit client (makeE "v_from" "v_to") Nothing
    hPutStrLn stderr ("Got Edge IDs: " <> show got_ids)
    length got_ids `shouldBe` 1
    let (q, qbind) = runBinder $ do
          eid <- newBind (got_ids !! 0)
          return $ gValues [ename_key] $. (sE' [eid] $ source "g")
    got_vals <- fmap V.toList $ WS.slurpResults =<< WS.submit client q (Just qbind)
    got_vals `shouldBe` ["e_test"]
    
    
