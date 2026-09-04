defmodule AwradServer.Tracking.Policy do
  @moduledoc false

  import Ecto.Changeset

  @named_thresholds ~w(any_positive minimum target maximum)

  def validate_thresholds(changeset, fields) do
    Enum.reduce(fields, changeset, &validate_threshold/2)
  end

  def validate_ordered_counts(changeset) do
    minimum = get_field(changeset, :minimum_count)
    target = get_field(changeset, :target_count)
    maximum = get_field(changeset, :maximum_count)

    changeset
    |> validate_order(
      :target_count,
      minimum,
      target,
      "must be greater than or equal to minimum_count"
    )
    |> validate_order(
      :maximum_count,
      target || minimum,
      maximum,
      "must be greater than or equal to target_count"
    )
  end

  defp validate_threshold(field, changeset) do
    case get_field(changeset, field) do
      %{"type" => type} when type in @named_thresholds ->
        changeset

      %{type: type} when type in @named_thresholds ->
        changeset

      %{"type" => "custom", "count" => count} when is_integer(count) and count > 0 ->
        changeset

      %{type: "custom", count: count} when is_integer(count) and count > 0 ->
        changeset

      _other ->
        add_error(
          changeset,
          field,
          "must select any_positive, minimum, target, maximum, or custom(count)"
        )
    end
  end

  defp validate_order(changeset, _field, nil, _upper, _message), do: changeset
  defp validate_order(changeset, _field, _lower, nil, _message), do: changeset

  defp validate_order(changeset, field, lower, upper, message) when upper < lower,
    do: add_error(changeset, field, message)

  defp validate_order(changeset, _field, _lower, _upper, _message), do: changeset
end
