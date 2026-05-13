defmodule IcgtWeb.TeamLiveTest do
  use IcgtWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Icgt.Repo
  alias Icgt.Tournaments.Team
  alias Icgt.Tournaments.TeamContactPerson

  test "lists teams", %{conn: conn} do
    team = insert_team!("Saenden zat. 2", "Saenden zaterdag 2")
    insert_contact!(team, "Jan Leider", "+31612345678")

    {:ok, _view, html} = live(admin_conn(conn), ~p"/teams")

    assert html =~ "Teambeheer"
    assert html =~ "Saenden zat. 2"
    assert html =~ "Saenden zaterdag 2"
    assert html =~ "1"
  end

  test "updates team broadcast name", %{conn: conn} do
    team = insert_team!("Saenden zat. 2", nil)

    {:ok, view, _html} = live(admin_conn(conn), ~p"/teams/#{team.id}")

    view
    |> form("#team-form", %{
      "team" => %{"name" => "Saenden zat. 2", "broadcast_name" => "Saenden zaterdag 2"}
    })
    |> render_submit()

    assert Repo.reload!(team).broadcast_name == "Saenden zaterdag 2"
  end

  test "adds updates and deletes contact people", %{conn: conn} do
    team = insert_team!("Saenden zat. 2", nil)

    {:ok, view, _html} = live(admin_conn(conn), ~p"/teams/#{team.id}")

    view
    |> form("#new-contact-form", %{
      "contact" => %{"id" => "", "name" => "Jan Leider", "phone_number" => "+31612345678"}
    })
    |> render_submit()

    contact = Repo.one!(TeamContactPerson)
    assert contact.name == "Jan Leider"

    view
    |> form("#contact-form-#{contact.id}", %{
      "contact" => %{
        "id" => contact.id,
        "name" => "Piet Leider",
        "phone_number" => "+31687654321"
      }
    })
    |> render_submit()

    contact = Repo.reload!(contact)
    assert contact.name == "Piet Leider"
    assert contact.phone_number == "+31687654321"

    view
    |> element("button[phx-click='delete_contact'][phx-value-id='#{contact.id}']")
    |> render_click()

    refute Repo.get(TeamContactPerson, contact.id)
  end

  test "requires basic auth for team pages", %{conn: conn} do
    conn = get(conn, ~p"/teams")

    assert response(conn, 401) =~ "Unauthorized"
    assert get_resp_header(conn, "www-authenticate") != []
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

  defp admin_conn(conn) do
    credentials = Base.encode64("ByteMe:BakkumMaakMeNouNietGek")
    put_req_header(conn, "authorization", "Basic #{credentials}")
  end
end
