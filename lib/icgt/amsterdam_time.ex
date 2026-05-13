defmodule Icgt.AmsterdamTime do
  @moduledoc false

  @timezone "Europe/Amsterdam"

  def timezone, do: @timezone

  def now do
    NaiveDateTime.local_now()
    |> NaiveDateTime.truncate(:second)
    |> as_stored_datetime()
  end

  def as_stored_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> as_stored_datetime()
  end

  def as_stored_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> DateTime.from_naive!("Etc/UTC")
  end
end
