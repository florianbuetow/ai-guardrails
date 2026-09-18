(ns com.example.testcliproject.fallback)

(defn token-or-placeholder [token]
  (or token "missing-token"))
