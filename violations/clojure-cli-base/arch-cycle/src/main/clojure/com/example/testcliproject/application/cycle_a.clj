(ns com.example.testcliproject.application.cycle-a
  (:require [com.example.testcliproject.domain.cycle-b :as cycle-b]))

(defn from-a []
  (cycle-b/from-b))
