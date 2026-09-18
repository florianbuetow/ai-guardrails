(ns com.example.testcliproject.contract-failure-test
  (:require [clojure.test :refer [deftest is]]
            [malli.core :as m]))

(defn greeting [_name]
  42)

(deftest rejects-invalid-contract-output
  (is (m/validate :string (greeting "Clojure"))))
