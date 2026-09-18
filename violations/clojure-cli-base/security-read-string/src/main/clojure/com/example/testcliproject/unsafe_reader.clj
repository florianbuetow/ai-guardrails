(ns com.example.testcliproject.unsafe-reader)

(defn parse-untrusted [source]
  (read-string source))
