defmodule AwradServer.MobileAppLinksTest do
  use ExUnit.Case, async: true

  test "disables an invalid optional iOS team id" do
    assert AwradServer.MobileAppLinks.ios_app_id("stale-team-value") == nil
  end

  test "disables malformed optional Android fingerprints" do
    assert AwradServer.MobileAppLinks.android_sha256_cert_fingerprints("stale-fingerprint") == []
  end
end
