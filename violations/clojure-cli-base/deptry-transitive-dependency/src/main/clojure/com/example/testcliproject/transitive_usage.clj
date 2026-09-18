(ns com.example.testcliproject.transitive-usage
  (:require [fipp.edn :as fipp]))

(defn pretty-print
  [value]
  (with-out-str (fipp/pprint value)))
