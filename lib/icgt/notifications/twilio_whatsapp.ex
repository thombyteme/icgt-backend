defmodule Icgt.Notifications.TwilioWhatsapp do
  @moduledoc false

  @endpoint "https://api.twilio.com/2010-04-01/Accounts"

  def send_message(to_phone_number, body) do
    with {:ok, config} <- twilio_config(),
         {:ok, to} <- normalize_whatsapp_number(to_phone_number),
         {:ok, from} <- normalize_whatsapp_number(config.from_phone_number),
         {:ok, response} <- deliver(config, from, to, body) do
      sid = get_in(response, ["sid"])

      if is_binary(sid) and sid != "" do
        {:ok, sid}
      else
        {:error, {:missing_message_sid, response}}
      end
    end
  end

  defp deliver(config, from, to, body) do
    url = "#{@endpoint}/#{config.account_sid}/Messages.json"

    form = [
      {"From", "whatsapp:#{from}"},
      {"To", "whatsapp:#{to}"},
      {"Body", body}
    ]

    case Req.post(url: url, auth: {:basic, config.account_sid, config.auth_token}, form: form) do
      {:ok, %{status: status, body: response}} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status, body: response}} ->
        {:error, {:twilio_request_failed, status, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp twilio_config do
    config = Application.get_env(:icgt, :twilio, [])
    account_sid = config[:account_sid]
    auth_token = config[:auth_token]
    from_phone_number = config[:from_phone_number]

    cond do
      is_nil(account_sid) or account_sid == "" ->
        {:error, :missing_twilio_account_sid}

      is_nil(auth_token) or auth_token == "" ->
        {:error, :missing_twilio_auth_token}

      is_nil(from_phone_number) or from_phone_number == "" ->
        {:error, :missing_twilio_from_phone_number}

      true ->
        {:ok,
         %{account_sid: account_sid, auth_token: auth_token, from_phone_number: from_phone_number}}
    end
  end

  defp normalize_whatsapp_number(nil), do: {:error, :missing_phone_number}

  defp normalize_whatsapp_number(number) when is_binary(number) do
    normalized =
      number
      |> String.trim()
      |> String.replace(~r/\s+/, "")

    if String.starts_with?(normalized, "+") and String.match?(normalized, ~r/^\+\d{8,15}$/) do
      {:ok, normalized}
    else
      {:error, {:invalid_phone_number, number}}
    end
  end
end
