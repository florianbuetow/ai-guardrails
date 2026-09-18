(ns com.example.testcliproject.suspicious-code)

(defn constant-test []
  (if false
    :unreachable
    :reachable))
