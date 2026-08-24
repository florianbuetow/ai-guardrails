defmodule Credo.Check.Custom.NoFallbackOperator do
  @moduledoc false
  use Credo.Check,
    id: "EX0002",
    base_priority: :high,
    category: :design,
    param_defaults: [],
    explanations: [
      check: """
      The || operator used as a fallback hides nil/false values.
      Use explicit nil checks and raise an error when the value is expected but missing.

      # Bad - hides nil with silent fallback
      endpoint = config_endpoint || "http://localhost:4000"

      # Good - require explicit value
      endpoint = config_endpoint
      if is_nil(endpoint), do: raise("endpoint is required")
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

  defp traverse({:||, meta, [_left, _right]} = ast, issues, issue_meta) do
    issue =
      format_issue(issue_meta,
        message:
          "The || operator used as a fallback hides nil/false values. " <>
            "Use explicit nil checks and raise an error when the value is expected but missing.",
        trigger: "||",
        line_no: meta[:line]
      )

    {ast, issues ++ [issue]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end
end
