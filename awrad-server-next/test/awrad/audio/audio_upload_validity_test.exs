defmodule Awrad.Audio.AudioUploadValidityTest do
  @moduledoc """
  contracts/audio/v1/fixtures/audio_upload_validity.json, one test per case,
  through `Awrad.Audio.Rules.check/3` (the check `create_audio_upload` runs
  after its `asset_id` lookup).
  """
  use ExUnit.Case, async: true

  alias Awrad.Audio.Rules
  alias Awrad.Fixtures

  for %{"id" => id, "given" => given, "expect" => expect} <-
        Fixtures.cases!("audio/v1", "audio_upload_validity") do
    @given given
    @expect expect
    test id do
      %{"byte_size" => byte_size, "content_type" => content_type, "used_bytes" => used} = @given

      result =
        case Rules.check(byte_size, content_type, used) do
          :ok -> %{"allowed" => true, "error" => nil}
          {:error, code} -> %{"allowed" => false, "error" => Atom.to_string(code)}
        end

      assert result == @expect
    end
  end
end
