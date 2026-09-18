(ns com.example.testcliproject.skipped-test
  (:require [clojure.test :refer [deftest is]]))

(deftest ^:kaocha/skip skipped-test
  (is false))
