-- RLS baseline for the intelligence layer.
-- Access model (internal platform):
--   * anon: no access at all.
--   * authenticated (signed-in staff): read everything; insert/update only the
--     human-input tables (complexity labels, annotations, proofreader feedback).
--   * Automation (n8n, backends) uses the service role, which bypasses RLS.

ALTER TABLE public.publications             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.letters                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.letter_complexity        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.letter_annotations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_datasets        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_dataset_letters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.model_inference_log      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proofreader_feedback     ENABLE ROW LEVEL SECURITY;

-- ── read access: all signed-in staff ─────────────────────────
CREATE POLICY "staff read publications"
  ON public.publications FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read letters"
  ON public.letters FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read letter_complexity"
  ON public.letter_complexity FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read letter_annotations"
  ON public.letter_annotations FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read training_datasets"
  ON public.training_datasets FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read training_dataset_letters"
  ON public.training_dataset_letters FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read model_inference_log"
  ON public.model_inference_log FOR SELECT TO authenticated USING (true);
CREATE POLICY "staff read proofreader_feedback"
  ON public.proofreader_feedback FOR SELECT TO authenticated USING (true);

-- ── write access: human-input tables only ────────────────────
-- Labeling tool: staff record complexity labels.
CREATE POLICY "staff insert letter_complexity"
  ON public.letter_complexity FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "staff update letter_complexity"
  ON public.letter_complexity FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

-- Annotation review: staff record correction pairs.
CREATE POLICY "staff insert letter_annotations"
  ON public.letter_annotations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "staff update letter_annotations"
  ON public.letter_annotations FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

-- Proofreading UI: staff accept/reject/modify model corrections.
CREATE POLICY "staff insert proofreader_feedback"
  ON public.proofreader_feedback FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "staff update proofreader_feedback"
  ON public.proofreader_feedback FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

-- Everything else (publications, letters, datasets, inference log) is written
-- exclusively by backends using the service role. No DELETE policies anywhere:
-- deletions are a service-role/administrative operation.
