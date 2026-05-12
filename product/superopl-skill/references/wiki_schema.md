# LLM-Wiki Schema for SuperOPL Knowledge Base

This schema is file-based (JSON/JSONL/Markdown), no DB required.

## Core Objects

### pages
- page-level metadata for wiki pages
- file: `knowledge_base/wiki/pages.json`
- fields: `page_id, title, kind, entity_id, source_task_id, updated_at`

### chunks
- retrieval chunks for LLM search/indexing
- file: `knowledge_base/wiki/chunks.jsonl`
- one JSON line per chunk
- fields: `chunk_id, page_id, entity_id, source_task_id, text, updated_at`

### entities
- normalized nodes (task/problem/measure/etc.)
- file: `knowledge_base/wiki/entities.json`
- fields: `entity_id, name, entity_type, source_task_id, status, responsible, owner, task_start, due_date, updated_at`

### edges
- graph relations between entities
- file: `knowledge_base/wiki/edges.json`
- fields: `edge_id, relation, source_entity_id, target_entity_id, weight, inferred_by, updated_at`
- includes:
  - `same_responsible` (sync-time baseline relation)
  - `problem_measure` (inferred in knowledge-link)

### confirmed_links
- human-confirmed problem->measure relations (priority over inferred)
- file: `knowledge_base/wiki/confirmed_links.json`
- fields: `link_id, relation, problem_id, measure_id, source_entity_id, target_entity_id, confirmed, confirmed_by, note, confirmed_at, updated_at`

### evidence
- traceability records from raw OPL facts and inferred links
- file: `knowledge_base/wiki/evidence.json`
- fields: `evidence_id, source_type, source_task_id, entity_id, captured_at, payload`

### revisions
- sync history snapshots
- file: `knowledge_base/wiki/revisions.json`
- fields: `revision_id, opl_id, synced_at, item_count, page_count, entity_count, evidence_count`

## Pipeline Mapping
- `opl_knowledge_sync.ps1`
  - rebuilds pages/chunks/entities/evidence/revisions
  - refreshes baseline edges (`same_responsible`)
- `opl_knowledge_link.ps1`
  - infers problem->measure links
  - writes to legacy links + wiki edges/evidence
- `opl_knowledge_confirm.ps1`
  - add/remove/list human-confirmed Problem-Measure links
- `opl_analyze.ps1`
  - reads both legacy stats and wiki artifacts for analysis output
  - prioritizes confirmed links, then falls back to inferred links
