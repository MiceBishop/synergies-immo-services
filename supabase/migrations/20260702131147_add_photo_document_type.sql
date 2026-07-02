-- Client feedback: buildings and locaux need photos/files, and tenants need
-- identity-proof files. The polymorphic `documents` table + `documents`
-- Storage bucket already exist; this adds a dedicated 'photo' value to the
-- document_type enum so building / unit images are typed meaningfully
-- (rather than falling back to 'other').
--
-- ALTER TYPE ... ADD VALUE is transactional on PG12+ as long as the new
-- value isn't used in the same transaction (it isn't here). IF NOT EXISTS
-- makes the migration safe to re-run.
alter type document_type add value if not exists 'photo';
