(ns com.example.testcliproject.failing-test
  (:require [clojure.test :refer [deftest is]]))

(deftest reports-failing-assertions
  (is (= "Hello, Clojure!" "Goodbye, Clojure!")))
