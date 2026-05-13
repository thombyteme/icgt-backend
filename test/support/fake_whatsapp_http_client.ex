defmodule Icgt.FakeWhatsAppHttpClient do
  def post(opts) do
    send(Application.fetch_env!(:icgt, :whatsapp_test_pid), {:whatsapp_post, opts})
    {:ok, %{status: 200, body: %{"messages" => [%{"id" => "wamid.fake"}]}}}
  end
end
