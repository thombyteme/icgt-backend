defmodule Icgt.Broadcasts.TextGeneratorTest do
  use ExUnit.Case, async: true

  alias Icgt.Broadcasts.TextGenerator
  alias Icgt.Tournaments.Match
  alias Icgt.Tournaments.Team

  test "generates a round announcement for multiple matches" do
    round_starts_at = ~U[2026-05-23 12:30:00Z]

    matches = [
      %Match{
        starts_at_local: ~N[2026-05-23 14:30:00],
        field: "2",
        poule: "Klasse 3",
        team_a_name: "HSV",
        team_b_name: "ADO'20 Spekkie",
        referee: "Kevin Blom"
      },
      %Match{
        starts_at_local: ~N[2026-05-23 14:30:00],
        field: "1",
        poule: "Dames",
        team_a_name: "Suteteest",
        team_b_name: "Vitesse'22 Veteranen",
        referee: "Bassie Nijhuis"
      }
    ]

    text = TextGenerator.round_announcement(round_starts_at, matches)

    assert text =~ "Voetballiefhebbers!"
    assert text =~ "ronde van half 3"
    assert text =~ "Op veld 1"
    assert text =~ "Suteteest tegen Vitesse'22 Veteranen onder begeleiding van Bassie Nijhuis."
    assert text =~ "Op veld 2"
    assert text =~ "HSV tegen ADO'20 Spekkie onder begeleiding van Kevin Blom."
  end

  test "uses fallbacks for missing match data" do
    text =
      TextGenerator.round_announcement(~U[2026-05-23 12:45:00Z], [
        %Match{field: nil, poule: nil, team_a_name: nil, team_b_name: "", referee: nil}
      ])

    assert text =~ "12:45"
    assert text =~ "Op een onbekend veld"
    assert text =~ "onbekende klasse"
    assert text =~ "onbekend team tegen onbekend team."
  end

  test "uses team broadcast names when available" do
    text =
      TextGenerator.round_announcement(~U[2026-05-23 12:00:00Z], [
        %Match{
          starts_at_local: ~N[2026-05-23 14:00:00],
          field: "1",
          poule: "Klasse 3",
          team_a_name: "Saenden zat. 2",
          team_b_name: "ADO'20 zat. 7",
          team_a: %Team{name: "Saenden zat. 2", broadcast_name: "Saenden zaterdag 2"},
          team_b: %Team{name: "ADO'20 zat. 7", broadcast_name: "ADO'20 zaterdag 7"}
        }
      ])

    assert text =~ "Saenden zaterdag 2 tegen ADO'20 zaterdag 7"
    refute text =~ "Saenden zat. 2"
    refute text =~ "ADO'20 zat. 7"
  end

  test "normalizes poule text for speech" do
    text =
      TextGenerator.round_announcement(~U[2026-05-23 16:30:00Z], [
        %Match{
          starts_at_local: ~N[2026-05-23 18:30:00],
          field: "1",
          poule: "Poule B - Klasse 3",
          team_a_name: "FC Uitgeest 5",
          team_b_name: "St. Adelbert",
          referee: "Eric Koning"
        }
      ])

    assert text =~ "uit Pool B Klasse 3 tegen elkaar"
    refute text =~ "Poule B - Klasse 3"
    refute text =~ "Poule"
    refute text =~ " -"
  end

  test "falls back to match team names when broadcast names are blank" do
    text =
      TextGenerator.round_announcement(~U[2026-05-23 12:00:00Z], [
        %Match{
          starts_at_local: ~N[2026-05-23 14:00:00],
          field: "1",
          poule: "Klasse 3",
          team_a_name: "Saenden zat. 2",
          team_b_name: "ADO'20 zat. 7",
          team_a: %Team{name: "Saenden zat. 2", broadcast_name: ""},
          team_b: %Team{name: "ADO'20 zat. 7", broadcast_name: nil}
        }
      ])

    assert text =~ "Saenden zat. 2 tegen ADO'20 zat. 7"
  end

  test "speaks whole evening hours in twelve-hour style" do
    text =
      TextGenerator.round_announcement(~U[2026-05-23 17:00:00Z], [
        %Match{
          starts_at_local: ~N[2026-05-23 19:00:00],
          field: "1",
          poule: "Klasse 2",
          team_a_name: "Team A",
          team_b_name: "Team B"
        }
      ])

    assert text =~ "ronde van 7 uur"
    refute text =~ "ronde van 19 uur"
  end

  test "generates referee whistle text" do
    assert TextGenerator.referee_whistle() == "Scheidsrechters! U mag affluiten!"
  end
end
