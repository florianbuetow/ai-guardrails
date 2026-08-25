(ns com.example.testcliproject.property-failure-test
  (:require [clojure.test.check.clojure-test :refer [defspec]]
            [clojure.test.check.generators :as gen]
            [clojure.test.check.properties :as prop]))

(defn non-negative-length [_value]
  -1)

(defspec generated-values-have-non-negative-length 20
  (prop/for-all [value gen/string]
    (nat-int? (non-negative-length value))))
