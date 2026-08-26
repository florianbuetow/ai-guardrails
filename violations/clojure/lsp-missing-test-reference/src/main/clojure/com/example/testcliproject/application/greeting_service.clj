(ns com.example.testcliproject.application.greeting-service
  (:require [com.example.testcliproject.domain.greeting :as greeting]))

(defn internal-greeting
  "Create a greeting before application-level adaptation."
  [recipient]
  (greeting/create recipient))

(defn create-greeting
  "Create a validated greeting for the recipient."
  [recipient]
  (internal-greeting recipient))
