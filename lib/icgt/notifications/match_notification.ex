defmodule Icgt.Notifications.MatchNotification do
  use Ecto.Schema
  import Ecto.Changeset

  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.TeamContactPerson

  schema "match_notifications" do
    belongs_to :match, Match
    belongs_to :team_contact_person, TeamContactPerson
    field :kind, :string
    field :status, :string
    field :provider_message_id, :string
    field :sent_at, :utc_datetime
    field :last_error, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :match_id,
      :team_contact_person_id,
      :kind,
      :status,
      :provider_message_id,
      :sent_at,
      :last_error
    ])
    |> validate_required([:match_id, :team_contact_person_id, :kind, :status])
    |> unique_constraint([:match_id, :team_contact_person_id, :kind])
  end
end
