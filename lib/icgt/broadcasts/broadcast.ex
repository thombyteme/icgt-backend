defmodule Icgt.Broadcasts.Broadcast do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ["round_announcement", "referee_whistle"]
  @statuses ["pending", "generated", "played", "failed"]

  schema "broadcasts" do
    field :kind, :string
    field :round_starts_at, :utc_datetime
    field :target_round_starts_at, :utc_datetime
    field :scheduled_for, :utc_datetime
    field :status, :string, default: "pending"
    field :text, :string
    field :audio_file_path, :string
    field :played_at, :utc_datetime
    field :last_error, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(broadcast, attrs) do
    broadcast
    |> cast(attrs, [
      :kind,
      :round_starts_at,
      :target_round_starts_at,
      :scheduled_for,
      :status,
      :text,
      :audio_file_path,
      :played_at,
      :last_error
    ])
    |> validate_required([
      :kind,
      :round_starts_at,
      :target_round_starts_at,
      :scheduled_for,
      :status,
      :text
    ])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:kind, :target_round_starts_at, :scheduled_for])
  end
end
