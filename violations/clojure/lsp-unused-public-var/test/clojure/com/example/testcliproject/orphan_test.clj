(ns com.example.testcliproject.orphan-test
  (:require [clojure.test :refer [deftest is]]
            [com.example.testcliproject.orphan :as orphan]))

(deftest orphaned-function-test
  (is (= :orphaned (orphan/orphaned-public-function))))
