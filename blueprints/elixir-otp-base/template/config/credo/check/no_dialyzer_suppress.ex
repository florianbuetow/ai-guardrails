defmodule Credo.Check.Custom.NoDialyzerSuppress do
  @moduledoc false
  use Credo.Check,
    id: "EX0004",
    base_priority: :high,
    category: :design,
    param_defaults: [],
    explanations: [
      check: """
      Dialyzer suppression is not allowed.
      Do NOT add or keep @dialyzer attributes that suppress warnings.
      Fix the underlying typing issue instead: adjust typespecs, add guards,
      correct return types, or refactor into typed helpers.

      # Bad - suppresses Dialyzer warnings
      @dialyzer {:nowarn_function, my_func: 1}
      @dialyzer :no_return

      # Good - fix the actual type issue
      @spec my_func(String.t()) :: {:ok, term()} | {:error, term()}
      def my_func(input) do
        ...
      end
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
    |> Enum.filter(&match?(%Credo.Issue{}, &1))
  end

  defp traverse({:@, meta, [{:dialyzer, _, _}]} = ast, issues, issue_meta) do
    issue =
      format_issue(issue_meta,
        message:
          "Dialyzer suppression is not allowed. " <>
            "Do NOT add or keep @dialyzer attributes that suppress warnings. " <>
            "Fix the underlying typing issue instead.",
        trigger: "@dialyzer",
        line_no: meta[:line]
      )

    {ast, issues ++ [issue]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end
end
