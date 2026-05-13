defmodule Icgt.Notifications do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Icgt.Notifications.MatchNotification
  alias Icgt.Repo

  @kind "whatsapp_10m"

  def kind, do: @kind

  def sent?(match_id, contact_person_id, kind \\ @kind) do
    Repo.exists?(
      from n in MatchNotification,
        where:
          n.match_id == ^match_id and
            n.team_contact_person_id == ^contact_person_id and
            n.kind == ^kind and
            n.status == "sent"
    )
  end

  def mark_sent(match_id, contact_person_id, provider_message_id, kind \\ @kind) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      match_id: match_id,
      team_contact_person_id: contact_person_id,
      kind: kind,
      status: "sent",
      provider_message_id: provider_message_id,
      sent_at: now,
      last_error: nil
    }

    upsert_notification(attrs)
  end

  def mark_failed(match_id, contact_person_id, error_text, kind \\ @kind) do
    attrs = %{
      match_id: match_id,
      team_contact_person_id: contact_person_id,
      kind: kind,
      status: "failed",
      last_error: String.slice(to_string(error_text), 0, 1000)
    }

    upsert_notification(attrs)
  end

  def all_sent_for_contacts?(match_id, contact_person_ids, kind \\ @kind) do
    expected = MapSet.new(contact_person_ids)

    sent_ids =
      Repo.all(
        from n in MatchNotification,
          where: n.match_id == ^match_id and n.kind == ^kind and n.status == "sent",
          select: n.team_contact_person_id
      )
      |> MapSet.new()

    MapSet.subset?(expected, sent_ids)
  end

  defp upsert_notification(attrs) do
    changeset = MatchNotification.changeset(%MatchNotification{}, attrs)

    Repo.insert(changeset,
      on_conflict: [
        set: [
          status: Map.fetch!(attrs, :status),
          provider_message_id: Map.get(attrs, :provider_message_id),
          sent_at: Map.get(attrs, :sent_at),
          last_error: Map.get(attrs, :last_error),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        ]
      ],
      conflict_target: [:match_id, :team_contact_person_id, :kind]
    )
  end
end
