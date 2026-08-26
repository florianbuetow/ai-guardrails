(ns com.example.testcliproject.application.greeting-service
  (:require [com.example.testcliproject.domain.greeting :as domain-greeting]))

(defn create-greeting
  "Create a validated greeting for the recipient."
  [recipient]
  (domain-greeting/create recipient))
