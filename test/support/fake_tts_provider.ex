defmodule Icgt.FakeTtsProvider do
  def generate_speech(text) do
    if String.contains?(text, "fail") do
      {:error, :fake_tts_failure}
    else
      {:ok, "fake mp3"}
    end
  end
end
