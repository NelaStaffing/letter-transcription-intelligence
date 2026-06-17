-- Intelligence layer database schema for letter transcription workflows.
-- This migration intentionally creates a standalone schema without any cross-database
-- foreign keys to the legacy automation database.

-- ─────────────────────────────────────────────
-- PUBLICATIONS
-- Replaces the per-publication table duplication
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.publications (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at    timestamptz NOT NULL DEFAULT now(),
  name          text NOT NULL UNIQUE,
  slug          text NOT NULL UNIQUE,
  is_active     boolean NOT NULL DEFAULT true,
  notes         text
);

-- ─────────────────────────────────────────────
-- LETTERS
-- Unified letter table — one row per letter across all publications
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.letters (
  id                      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at              timestamptz NOT NULL DEFAULT now(),

  -- Soft link to old DB (no cross-DB FK — just a stored ID)
  legacy_transcript_id    bigint,
  publication_id          bigint NOT NULL REFERENCES public.publications(id),

  -- Identity
  document_name           text,
  letter_date             date,
  letter_author           text,
  church_district         text,
  state_postal_name       text,

  -- Files
  pdf_file_url            text,
  dropbox_url             text,
  word_file_url           text,

  -- Transcription
  text_transcription      text,
  processing_status       text
);

-- ─────────────────────────────────────────────
-- LETTER COMPLEXITY
-- Output of the 500-letter manual labeling tool (and future auto-classifier)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.letter_complexity (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at       timestamptz NOT NULL DEFAULT now(),
  letter_id        bigint NOT NULL REFERENCES public.letters(id),

  complexity_level smallint NOT NULL CHECK (complexity_level BETWEEN 1 AND 6),
  scan_quality     smallint NOT NULL CHECK (scan_quality BETWEEN 1 AND 5),
  length           text NOT NULL CHECK (length IN ('short', 'medium', 'long')),
  labels           text[],
  notes            text,

  labeled_by       text,
  labeled_at       timestamptz DEFAULT now(),
  source           text NOT NULL DEFAULT 'manual'
                   CHECK (source IN ('manual', 'model'))
);

-- ─────────────────────────────────────────────
-- LETTER ANNOTATIONS (Option B)
-- Structured correction pairs extracted from auto-transcription vs. proofread diffs
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.letter_annotations (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at         timestamptz NOT NULL DEFAULT now(),
  letter_id          bigint NOT NULL REFERENCES public.letters(id),

  original_span      text NOT NULL,
  corrected_span     text NOT NULL,
  correction_type    text NOT NULL CHECK (correction_type IN (
                       'homophone',
                       'proper_noun',
                       'missing_word',
                       'extra_word',
                       'abbreviation',
                       'punctuation',
                       'explicit_flag',
                       'semantic_error'
                     )),
  confidence         text NOT NULL DEFAULT 'high'
                     CHECK (confidence IN ('high', 'medium', 'low')),
  notes              text,

  annotated_by       text,
  annotation_source  text NOT NULL DEFAULT 'human_diff'
                     CHECK (annotation_source IN ('human_diff', 'model_inference'))
);

-- ─────────────────────────────────────────────
-- TRAINING DATASETS
-- Versioned snapshots of which letters + annotations go into each training run
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.training_datasets (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at       timestamptz NOT NULL DEFAULT now(),

  name             text NOT NULL,
  description      text,
  schema_version   text NOT NULL,
  letter_count     integer,
  annotation_count integer,
  status           text NOT NULL DEFAULT 'building'
                   CHECK (status IN ('building', 'ready', 'archived')),
  dataset_url      text,
  notes            text
);

-- Junction: which letters belong to which dataset version
CREATE TABLE IF NOT EXISTS public.training_dataset_letters (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dataset_id  bigint NOT NULL REFERENCES public.training_datasets(id),
  letter_id   bigint NOT NULL REFERENCES public.letters(id),
  UNIQUE (dataset_id, letter_id)
);

-- ─────────────────────────────────────────────
-- MODEL INFERENCE LOG
-- Every time the semantic proofreading agent runs on a letter
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.model_inference_log (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at           timestamptz NOT NULL DEFAULT now(),
  letter_id            bigint NOT NULL REFERENCES public.letters(id),

  model_name           text NOT NULL,
  model_version        text,
  input_text           text,
  output_text          text,
  corrections_applied  jsonb,
  latency_ms           integer,
  status               text CHECK (status IN ('success', 'error', 'skipped')),
  error_message        text
);

-- ─────────────────────────────────────────────
-- PROOFREADER FEEDBACK (The feedback loop)
-- Captures what proofreaders do with model output → future training signal
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.proofreader_feedback (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at        timestamptz NOT NULL DEFAULT now(),
  inference_id      bigint NOT NULL REFERENCES public.model_inference_log(id),
  letter_id         bigint NOT NULL REFERENCES public.letters(id),

  original_span     text,
  model_correction  text,
  human_correction  text,
  action            text NOT NULL CHECK (action IN (
                      'accepted',
                      'rejected',
                      'modified'
                    )),
  proofreader_id    text,
  notes             text
);

-- Common lookup indexes for relationships and migration backfills.
CREATE INDEX IF NOT EXISTS idx_letters_publication_id ON public.letters(publication_id);
CREATE INDEX IF NOT EXISTS idx_letters_legacy_transcript_id ON public.letters(legacy_transcript_id);
CREATE INDEX IF NOT EXISTS idx_letter_complexity_letter_id ON public.letter_complexity(letter_id);
CREATE INDEX IF NOT EXISTS idx_letter_annotations_letter_id ON public.letter_annotations(letter_id);
CREATE INDEX IF NOT EXISTS idx_training_dataset_letters_dataset_id ON public.training_dataset_letters(dataset_id);
CREATE INDEX IF NOT EXISTS idx_training_dataset_letters_letter_id ON public.training_dataset_letters(letter_id);
CREATE INDEX IF NOT EXISTS idx_model_inference_log_letter_id ON public.model_inference_log(letter_id);
CREATE INDEX IF NOT EXISTS idx_proofreader_feedback_inference_id ON public.proofreader_feedback(inference_id);
CREATE INDEX IF NOT EXISTS idx_proofreader_feedback_letter_id ON public.proofreader_feedback(letter_id);
