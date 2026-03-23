# Design Justification

## Storage Systems

Four storage systems were chosen, each matched to the specific access pattern of its goal rather than forcing all data into one general-purpose database.

**Goal 4 — ICU vitals: Time-series DB (InfluxDB / TimescaleDB).** Sensor readings are always appended, never updated, and queried almost exclusively by time range. General-purpose relational databases struggle with the write throughput and compression efficiency this demands. TimescaleDB offers columnar storage per time window, automatic downsampling, and sub-millisecond range queries without index bloat.

**Goals 1 & 3 — EHR records: Relational DB (PostgreSQL).** Structured patient data has well-defined schemas and deeply relational structure across admissions, medications, and labs. ACID guarantees are non-negotiable: a partial write that records a drug prescription without completing the allergy-check update could directly harm a patient. 

**Goal 2 — Plain-English search: Vector DB (Pinecone / pgvector).** Keyword search fails here because clinical language is paraphrastic — "myocardial infarction", "heart attack", and "STEMI" describe the same event but share no words. The vector database stores dense embeddings of clinical notes; queries are encoded into the same semantic space and approximate nearest-neighbour search retrieves relevant passages regardless of exact wording. 

**Goal 3 — Reporting: Data Warehouse (Snowflake / BigQuery).** Monthly reports require heavy aggregations across years of history. Running these on the operational PostgreSQL instance would create read contention that slows patient-facing queries. The warehouse receives a daily ETL copy and serves OLAP workloads in isolation, preventing heavy aggregations from contending with operational reads.

## OLTP vs OLAP Boundary

The transactional system ends at PostgreSQL. All writes that touch live patient data — new admissions, prescriptions, lab results — land there first. It is the system of record: always consistent and current.

The analytical system begins at the data warehouse. A nightly Airflow-orchestrated, dbt-transformed job extracts aggregated, non-PHI summaries from PostgreSQL and loads them into Snowflake. The warehouse is strictly read-only from an operational standpoint, so a management team running a multi-year cost query cannot lock rows a nurse is simultaneously updating. The boundary is enforced physically, not just logically.

The vector database sits outside both boundaries: populated once when a clinical note is finalised and embedded, thereafter serving only read queries from the RAG pipeline.

## Trade-offs

**The most significant trade-off is model freshness versus training simplicity.**

The readmission model is trained on historical EHR batch data. Feature distributions drift as clinical practice evolves — new medications, changed coding conventions — degrading accuracy silently.

The mitigation is two-part. First, the Kafka real-time vitals pipeline feeds live physiological features at inference time alongside the static EHR features, so the model always sees current patient state even when administrative records lag. Second, a weekly monitoring job compares live feature distributions and output score distributions against the training baseline using population stability index. When drift exceeds a threshold, an automated retraining job runs against the latest EHR snapshot. This keeps the model accurate without requiring a fully online learning architecture, which would add significant infrastructure risk in a regulated clinical environment.
