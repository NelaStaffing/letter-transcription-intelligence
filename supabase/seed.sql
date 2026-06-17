-- Seed baseline publications for the intelligence layer.
INSERT INTO public.publications (name, slug, notes)
VALUES
  ('Die Botschaft', 'die-botschaft', 'Seed publication for the unified intelligence layer schema.'),
  ('The Budget', 'the-budget', 'Seed publication for the unified intelligence layer schema.'),
  ('Ivverich & Ender', 'ivverich-ender', 'Seed publication for the unified intelligence layer schema.')
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name,
    notes = EXCLUDED.notes;
