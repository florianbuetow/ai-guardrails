defmodule Credo.Check.Custom.NoMapGetDefault do
  @moduledoc false
  use Credo.Check,
    id: "EX0003",
    base_priority: :high,
    category: :design,
    param_defaults: [],
    explanations: [
      check: """
      Using Map.get/3 with a default value hides missing configuration.
      Access the key directly with Map.fetch!/2 or use explicit validation instead.

      # Bad - default hides missing key
      port = Map.get(config, :port, 4000)

      # Good - fail explicitly on missing key
      port = Map.fetch!(config, :port)

      # Also good - explicit validation
      case Map.fetch(config, :port) do
        {:ok, port} -> port
        :error -> raise "port is required in config"
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

  # Match Map.get/3 (with default argument)
  defp traverse(
         {{:., _, [{:__aliases__, _, [:Map]}, :get]}, meta, [_map, _key, _default]} = ast,
         issues,
         issue_meta
       ) do
    issue =
      format_issue(issue_meta,
        message:
          "Map.get/3 with a default value hides missing configuration. " <>
            "Use Map.fetch!/2 or explicit validation with Map.fetch/2 instead.",
        trigger: "Map.get",
        line_no: meta[:line]
      )

    {ast, issues ++ [issue]}
  end

  # Match Keyword.get/3 (with default argument)
  defp traverse(
         {{:., _, [{:__aliases__, _, [:Keyword]}, :get]}, meta, [_list, _key, _default]} = ast,
         issues,
         issue_meta
       ) do
    issue =
      format_issue(issue_meta,
        message:
          "Keyword.get/3 with a default value hides missing configuration. " <>
            "Use Keyword.fetch!/2 or explicit validation with Keyword.fetch/2 instead.",
        trigger: "Keyword.get",
        line_no: meta[:line]
      )

    {ast, issues ++ [issue]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end
end
