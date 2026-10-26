defmodule AwradWeb.LocaleTest do
  use ExUnit.Case, async: true

  alias AwradWeb.Locale

  doctest Locale

  test "picks the most preferred supported language" do
    assert Locale.parse("ar") == "ar"
    assert Locale.parse("ml-IN") == "ml"
    assert Locale.parse("fr-FR, ar;q=0.5, ml;q=0.8") == "ml"
    assert Locale.parse("en;q=0.1, AR;q=0.9") == "ar"
  end

  test "falls back to en" do
    assert Locale.parse("") == "en"
    assert Locale.parse("fr, de") == "en"
    assert Locale.parse("ar;q=0") == "en"
    assert Locale.parse("ar;q=bogus") == "en"
    assert Locale.parse(String.duplicate("ar,", 100)) == "en"
  end
end
