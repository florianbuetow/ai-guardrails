defmodule Credo.Check.Custom.NoDefaultParameterValues do
  @moduledoc false
  use Credo.Check,
    id: "EX0001",
    base_priority: :high,
    category: :design,
    param_defaults: [],
    explanations: [
      check: """
      Default parameter values hide configuration errors.
      Use explicit required parameters and validate at the call site instead,
      or raise an error when a parameter is unexpectedly missing.

      # Bad - default hides missing configuration
      def connect(host \\\\ "localhost", port \\\\ 4000) do
        ...
      end

      # Good - require explicit values
      def connect(host, port) do
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

  defp traverse({op, meta, [{name, _, args} | _]} = ast, issues, issue_meta)
       when op in [:def, :defp] and is_atom(name) and is_list(args) do
    new_issues =
      args
      |> Enum.filter(&has_default?/1)
      |> Enum.map(fn _arg ->
        format_issue(issue_meta,
          message:
            "Default parameter value in #{op} #{name}/#{length(args)} hides configuration errors. " <>
              "Use explicit required parameters instead.",
          trigger: "#{name}",
          line_no: meta[:line]
        )
      end)

    {ast, issues ++ new_issues}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp has_default?({:\\, _meta, _args}), do: true
  defp has_default?(_), do: false
end
