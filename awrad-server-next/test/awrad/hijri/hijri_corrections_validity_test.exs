defmodule Awrad.Hijri.HijriCorrectionsValidityTest do
  @moduledoc """
  contracts/hijri-calendar/v1/fixtures/hijri_corrections_validity.json, one
  test per case, through `Corrections.new/1`.
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures
  alias Awrad.Fixtures.HijriCalendar
  alias Awrad.Hijri.Corrections

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("hijri-calendar/v1", "hijri_corrections_validity") do
    @given given
    @expect expect
    test id do
      result = @given["corrections"] |> HijriCalendar.corrections() |> Corrections.new()

      assert HijriCalendar.encode_validity(result) == @expect
    end
  end
end
