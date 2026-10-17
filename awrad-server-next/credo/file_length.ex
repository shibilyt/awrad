defmodule AwradCredo.FileLength do
  @moduledoc """
  Fails when a production source file grows past `max_lines` (default 400),
  the same limit awrad-android-next enforces. Large files are where rules hide
  inside controllers; split by responsibility before this trips.
  """

  use Credo.Check,
    id: "AW001",
    base_priority: :high,
    category: :design,
    param_defaults: [max_lines: 400],
    explanations: [
      check: "Production files stay under the line limit so each has one responsibility.",
      params: [max_lines: "Maximum number of lines per file."]
    ]

  @impl Credo.Check
  def run(%SourceFile{} = source_file, params) do
    max = Params.get(params, :max_lines, __MODULE__)
    # Count lines the way `wc -l` does: a trailing newline doesn't start a new line.
    lines = source_file |> SourceFile.source() |> String.trim_trailing("\n") |> String.split("\n") |> length()

    if lines > max do
      [
        format_issue(IssueMeta.for(source_file, params),
          message: "File has #{lines} lines; the limit is #{max}. Split it by responsibility.",
          line_no: 1
        )
      ]
    else
      []
    end
  end
end
