defmodule Icgt.Workers.NotifyUpcomingMatchesWorkerTest do
  use Icgt.DataCase

  alias Icgt.AmsterdamTime
  alias Icgt.Notifications.MatchNotification
  alias Icgt.Repo
  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.Team
  alias Icgt.Tournaments.TeamContactPerson
  alias Icgt.Workers.NotifyUpcomingMatchesWorker

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

  test "sends the match template to both teams with team-specific variables" do
    team_a = insert_team!("Saenden zat. 2", "Saenden zaterdag 2")
    team_b = insert_team!("ADO'20 zat. 7", "ADO'20 zaterdag 7")
    insert_contact!(team_a, "Leider A", "+31611111111")
    insert_contact!(team_b, "Leider B", "+31622222222")

    starts_at = AmsterdamTime.now() |> DateTime.add(10 * 60 + 30, :second)

    insert_match!(%{
      starts_at: starts_at,
      starts_at_local: DateTime.to_naive(starts_at),
      field: "1",
      team_a_name: "Saenden zat. 2",
      team_b_name: "ADO'20 zat. 7",
      team_a_id: team_a.id,
      team_b_id: team_b.id
    })

    assert :ok = NotifyUpcomingMatchesWorker.perform(%Oban.Job{})

    assert Repo.aggregate(MatchNotification, :count) == 2

    requests = receive_whatsapp_requests(2)

    assert %{
             to: "31611111111",
             template: %{
               name: "icgt_match_notification",
               language: %{code: "nl"},
               components: [%{parameters: team_a_parameters}]
             }
           } = Enum.find(requests, &(&1.to == "31611111111"))

    assert parameters_to_map(team_a_parameters) == %{
             "team" => "Saenden zaterdag 2",
             "veld_nummer" => "1",
             "tegenstander_team" => "ADO'20 zaterdag 7"
           }

    assert %{
             to: "31622222222",
             template: %{
               name: "icgt_match_notification",
               language: %{code: "nl"},
               components: [%{parameters: team_b_parameters}]
             }
           } = Enum.find(requests, &(&1.to == "31622222222"))

    assert parameters_to_map(team_b_parameters) == %{
             "team" => "ADO'20 zaterdag 7",
             "veld_nummer" => "1",
             "tegenstander_team" => "Saenden zaterdag 2"
           }
  end

  defp receive_whatsapp_requests(count) do
    Enum.map(1..count, fn _ ->
      assert_receive {:whatsapp_post, opts}
      opts[:json]
    end)
  end

  defp parameters_to_map(parameters) do
    Map.new(parameters, fn parameter -> {parameter.parameter_name, parameter.text} end)
  end

  defp insert_team!(name, broadcast_name) do
    %Team{}
    |> Team.changeset(%{name: name, broadcast_name: broadcast_name})
    |> Repo.insert!()
  end

  defp insert_contact!(team, name, phone_number) do
    %TeamContactPerson{}
    |> TeamContactPerson.changeset(%{
      team_id: team.id,
      name: name,
      phone_number: phone_number
    })
    |> Repo.insert!()
  end

  defp insert_match!(attrs) do
    defaults = %{
      source: "test",
      external_id: "test-match",
      unique_key: "test-match",
      starts_at: AmsterdamTime.now(),
      starts_at_local: NaiveDateTime.local_now() |> NaiveDateTime.truncate(:second),
      timezone: "Europe/Amsterdam",
      field: "1",
      date_iso: Date.utc_today(),
      poule: "Klasse 1",
      referee: "Scheidsrechter",
      team_a_name: "Team A",
      team_b_name: "Team B",
      status: "scheduled",
      raw_data: %{}
    }

    %Match{}
    |> Match.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
