(ns guardrails.require-test-reference
  (:require [clojure-lsp.custom-linters-api :as api]
            [clojure.string :as str]))

(def ^:private production-source-fragment "/src/main/clojure/")
(def ^:private test-source-fragment "/test/clojure/")
(def ^:private public-definition-forms
  #{'clojure.core/def 'clojure.core/defn 'clojure.core/defmacro})

(defn- production-definition?
  [requested-uris definition]
  (and (contains? requested-uris (:uri definition))
       (str/includes? (:uri definition) production-source-fragment)
       (contains? public-definition-forms (:defined-by definition))
       (not= '-main (:name definition))))

(defn- test-reference?
  [reference]
  (str/includes? (:uri reference) test-source-fragment))

(defn- diagnostic-range
  [definition]
  {:row (:name-row definition)
   :col (:name-col definition)
   :end-row (:name-end-row definition)
   :end-col (:name-end-col definition)})

(defn lint
  "Report public production vars that have no reference from test code."
  [{:keys [db params reg-diagnostic! uris]}]
  (let [requested-uris (set (api/dir-uris->file-uris uris db))]
    (doseq [definition (api/find-all-var-definitions db false)
            :when (production-definition? requested-uris definition)
            :when (not-any? test-reference? (api/find-references db definition false))]
      (reg-diagnostic!
       {:uri (:uri definition)
        :level (:level params)
        :code "guardrails/missing-test-reference"
        :message "Public production vars must be referenced by a test"
        :source "guardrails/require-test-reference"
        :range (diagnostic-range definition)}))))
