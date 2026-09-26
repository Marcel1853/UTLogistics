-- Den Wende-Greifarm gab es nur in der Entwicklungsfassung von 0.0.8, er ist wieder entfernt (seine
-- Entities entfernt Factorio beim Laden selbst). Übrig gebliebene Tabellen aufräumen. Läuft einmal
-- je Spielstand, vor on_configuration_changed.
storage.reversible = nil
storage.rev_open = nil
