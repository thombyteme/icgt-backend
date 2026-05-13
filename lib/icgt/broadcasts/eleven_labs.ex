defmodule Icgt.Broadcasts.ElevenLabs do
  @moduledoc false

  @api_url "https://api.elevenlabs.io/v1/text-to-speech"
  @default_voice_id "XSQQLeoHwWnBv8tjJ1T7"
  @default_model "eleven_flash_v2_5"

  def generate_speech(text) do
    with {:ok, config} <- config(),
         {:ok, response} <- request_speech(config, text) do
      {:ok, response}
    end
  end

  defp request_speech(config, text) do
    body = %{
      text: text,
      model_id: config.model,
      voice_settings: %{
        speed: 0.9,
        stability: 0.48,
        similarity_boost: 0.75
      }
    }

    url = "#{@api_url}/#{config.voice_id}"

    case Req.post(
           url: url,
           json: body,
           headers: [
             {"xi-api-key", config.api_key},
             {"Accept", "audio/mpeg"}
           ]
         ) do
      {:ok, %{status: status, body: audio}} when status in 200..299 ->
        {:ok, audio}

      {:ok, %{status: status, body: response}} ->
        {:error, {:eleven_labs_request_failed, status, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp config do
    config = Application.get_env(:icgt, :eleven_labs, [])
    api_key = config[:api_key]

    if is_binary(api_key) and api_key != "" do
      {:ok,
       %{
         api_key: api_key,
         voice_id: config[:voice_id] || @default_voice_id,
         model: config[:model] || @default_model
       }}
    else
      {:error, :missing_eleven_labs_api_key}
    end
  end
end
