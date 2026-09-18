(ns com.example.testcliproject.insecure-token)

(defn token []
  (.nextInt (java.util.Random.) 1000000))
