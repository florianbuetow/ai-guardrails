(ns com.example.testcliproject.domain.forbidden-dependency
  (:require [com.example.testcliproject.cli.main :as cli]))

(defn run-cli-from-domain []
  (cli/-main))
