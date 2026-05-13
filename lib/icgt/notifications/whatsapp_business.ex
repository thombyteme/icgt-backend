defmodule Icgt.Notifications.WhatsAppBusiness do
  @moduledoc false

  @graph_api_base "https://graph.facebook.com/v22.0"
  @default_match_template_name "icgt_match_notification"
  @default_language "nl"

  def send_match_notification(to_phone_number, variables) do
    with {:ok, config} <- whatsapp_config(),
         {:ok, to} <- normalize_whatsapp_number(to_phone_number),
         {:ok, response} <- deliver_template(config, to, variables) do
      response_message_id(response)
    end
  end

  defp deliver_template(config, to, variables) do
    url = "#{@graph_api_base}/#{config.phone_number_id}/messages"

    body = %{
      messaging_product: "whatsapp",
      to: to,
      type: "template",
      template: %{
        name: config.match_template_name,
        language: %{code: config.language},
        components: [
          %{
            type: "body",
            parameters: [
              template_parameter("team", variables),
              template_parameter("veld_nummer", variables),
              template_parameter("tegenstander_team", variables)
            ]
          }
        ]
      }
    }

    post_json(config, url, body)
  end

  defp template_parameter(name, variables) do
    %{
      type: "text",
      parameter_name: name,
      text: variables[name] || variables[String.to_atom(name)] || "-"
    }
  end

  defp post_json(config, url, body) do
    http_client = Application.get_env(:icgt, :whatsapp_http_client, Req)

    case http_client.post(
           url: url,
           json: body,
           headers: [
             {"Authorization", "Bearer #{config.access_token}"},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: response}} when status in 200..299 ->
        {:ok, response}

      {:ok, %{status: status, body: response}} ->
        {:error, {:whatsapp_request_failed, status, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp response_message_id(response) do
    message_id = get_in(response, ["messages", Access.at(0), "id"])

    if is_binary(message_id) and message_id != "" do
      {:ok, message_id}
    else
      {:error, {:missing_whatsapp_message_id, response}}
    end
  end

  defp whatsapp_config do
    config = Application.get_env(:icgt, :whatsapp_business, [])
    phone_number_id = config[:phone_number_id]
    access_token = config[:access_token]
    match_template_name = config[:match_template_name] || @default_match_template_name
    language = config[:language] || @default_language

    cond do
      is_nil(phone_number_id) or phone_number_id == "" ->
        {:error, :missing_whatsapp_business_phone_number_id}

      is_nil(access_token) or access_token == "" ->
        {:error, :missing_whatsapp_business_access_token}

      true ->
        {:ok,
         %{
           phone_number_id: phone_number_id,
           access_token: access_token,
           match_template_name: match_template_name,
           language: language
         }}
    end
  end

  defp normalize_whatsapp_number(nil), do: {:error, :missing_phone_number}

  defp normalize_whatsapp_number(number) when is_binary(number) do
    normalized =
      number
      |> String.trim()
      |> String.replace(~r/\s+/, "")
      |> String.trim_leading("+")

    if String.match?(normalized, ~r/^\d{8,15}$/) do
      {:ok, normalized}
    else
      {:error, {:invalid_phone_number, number}}
    end
  end
end
