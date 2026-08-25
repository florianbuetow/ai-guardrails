/*
rule = NoUnsafeOptionGet
 */
package guardrails

object NoUnsafeOptionGetInput {
  val unsafe = Option(1).get // assert: NoUnsafeOptionGet.NoUnsafeOptionGet
}
