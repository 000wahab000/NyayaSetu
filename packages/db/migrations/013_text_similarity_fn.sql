-- Helper RPC: pg_trgm text similarity between two complaint descriptions
CREATE OR REPLACE FUNCTION text_similarity(complaint_a UUID, complaint_b UUID)
RETURNS FLOAT AS $$
DECLARE
  text_a TEXT;
  text_b TEXT;
BEGIN
  SELECT description_text INTO text_a FROM complaints WHERE id = complaint_a;
  SELECT description_text INTO text_b FROM complaints WHERE id = complaint_b;
  IF text_a IS NULL OR text_b IS NULL THEN RETURN 0; END IF;
  RETURN similarity(text_a, text_b);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
