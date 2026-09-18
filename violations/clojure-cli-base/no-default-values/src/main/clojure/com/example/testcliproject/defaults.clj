(ns com.example.testcliproject.defaults)

(defn display-name [{:keys [name] :or {name "anonymous"}}]
  name)
