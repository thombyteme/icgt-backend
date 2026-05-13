defmodule Icgt.AmsterdamTimeTest do
  use ExUnit.Case, async: true

  alias Icgt.AmsterdamTime

  test "stores naive Amsterdam wall-clock time as an Etc/UTC datetime without shifting the hour" do
    assert AmsterdamTime.as_stored_datetime(~N[2026-05-23 19:00:00]) ==
             ~U[2026-05-23 19:00:00Z]
  end

  test "keeps DateTime wall-clock fields instead of shifting zones" do
    assert AmsterdamTime.as_stored_datetime(~U[2026-05-23 17:00:00Z]) ==
             ~U[2026-05-23 17:00:00Z]
  end
end
