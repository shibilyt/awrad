defmodule AwradWeb.ErrorJSONTest do
  use ExUnit.Case, async: true

  test "renders a 404 as a problem with a stable code" do
    assert %{code: "not_found", status: 404, type: "urn:awrad:problem:not_found", errors: []} =
             AwradWeb.ErrorJSON.render("404.json", %{})
  end

  test "renders a 500 without internal details" do
    assert %{code: "internal_error", status: 500, detail: "Internal server error"} =
             AwradWeb.ErrorJSON.render("500.json", %{})
  end
end
