(ns com.example.testcliproject.domain.cycle-b
  (:require [com.example.testcliproject.application.cycle-a :as cycle-a]))

(defn from-b []
  (cycle-a/from-a))
