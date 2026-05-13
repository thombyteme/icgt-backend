defmodule Icgt.Notifications.WhatsAppBusinessTest do
  use ExUnit.Case, async: false

  alias Icgt.Notifications.WhatsAppBusiness

  setup do
    Application.put_env(:icgt, :whatsapp_test_pid, self())
    Application.put_env(:icgt, :whatsapp_http_client, Icgt.FakeWhatsAppHttpClient)

    Application.put_env(:icgt, :whatsapp_business,
      phone_number_id: "123456",
      access_token: "secret",
      match_template_name: "icgt_match_notification",
      language: "nl"
    )

    on_exit(fn ->
      Application.delete_env(:icgt, :whatsapp_test_pid)
      Application.delete_env(:icgt, :whatsapp_http_client)
      Application.delete_env(:icgt, :whatsapp_business)
    end)

    :ok
  end

  test "sends the ICGT match notification template by name with named body parameters" do
    assert {:ok, "wamid.fake"} =
             WhatsAppBusiness.send_match_notification("+31612345678", %{
               "team" => "Saenden zaterdag 2",
               "veld_nummer" => "1",
               "tegenstander_team" => "ADO'20 zaterdag 7"
             })

    assert_received {:whatsapp_post, opts}

    assert opts[:url] == "https://graph.facebook.com/v22.0/123456/messages"
    assert {"Authorization", "Bearer secret"} in opts[:headers]
    assert {"Content-Type", "application/json"} in opts[:headers]

    assert opts[:json] == %{
             messaging_product: "whatsapp",
             to: "31612345678",
             type: "template",
             template: %{
               name: "icgt_match_notification",
               language: %{code: "nl"},
               components: [
                 %{
                   type: "body",
                   parameters: [
                     %{
                       type: "text",
                       parameter_name: "team",
                       text: "Saenden zaterdag 2"
                     },
                     %{type: "text", parameter_name: "veld_nummer", text: "1"},
                     %{
                       type: "text",
                       parameter_name: "tegenstander_team",
                       text: "ADO'20 zaterdag 7"
                     }
                   ]
                 }
               ]
             }
           }
  end

  test "requires WhatsApp Business API credentials" do
    Application.put_env(:icgt, :whatsapp_business,
      phone_number_id: nil,
      access_token: "secret",
      match_template_name: "icgt_match_notification",
      language: "nl"
    )

    assert {:error, :missing_whatsapp_business_phone_number_id} =
             WhatsAppBusiness.send_match_notification("+31612345678", %{
               "team" => "Team",
               "veld_nummer" => "1",
               "tegenstander_team" => "Opponent"
             })
  end
end
