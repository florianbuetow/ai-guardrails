(ns com.example.testcliproject.suppressed)

#_{:clj-kondo/ignore [:unused-binding]}
(defn suppressed-binding []
  (let [unused-value 1]
    2))
