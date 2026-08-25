package guardrails

import scala.meta.Term
import scalafix.v1.Diagnostic
import scalafix.v1.Patch
import scalafix.v1.SemanticDocument
import scalafix.v1.SemanticRule
import scalafix.v1.SymbolMatcher
import scalafix.v1.XtensionTreeScalafix

class NoUnsafeOptionGet extends SemanticRule("NoUnsafeOptionGet") {
  override def fix(implicit document: SemanticDocument): Patch =
    document.tree.collect {
      case name: Term.Name
          if name.value == "get" && NoUnsafeOptionGet.optionGet.matches(name.symbol) =>
        Patch.lint(
          Diagnostic(
            "NoUnsafeOptionGet",
            "Option.get is partial; pattern match and handle both cases explicitly",
            name.pos
          )
        )
    }.asPatch
}

object NoUnsafeOptionGet {
  private val optionGet = SymbolMatcher.normalized("scala/Option#get().")
}
