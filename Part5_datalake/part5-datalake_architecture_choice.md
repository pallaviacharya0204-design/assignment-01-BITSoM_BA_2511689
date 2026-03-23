# Architecture Choice

## Architecture Recommendation

**Recommendation: Data Lakehouse**

A fast-growing food delivery startup collecting GPS logs, customer text reviews, payment transactions, and restaurant menu images is dealing with four fundamentally different data types that no single traditional architecture handles well in isolation. A Data Lakehouse — which layers transactional guarantees and SQL query capability on top of cheap object storage — is the right choice for three specific reasons.

**1. The data is structurally heterogeneous and a warehouse schema cannot contain it.** Payment transactions are relational and fit a fixed schema. GPS logs are high-frequency time-series with variable attributes. Customer reviews are unstructured free text. Menu images are binary blobs. A traditional Data Warehouse demands every dataset be cleaned and modelled into rigid schemas before loading — images and raw GPS streams simply cannot be forced into that model. A Data Lake accepts all formats natively, and the Lakehouse adds Delta Lake or Apache Iceberg table formats on top so the structured subset (payments, order history) still gets ACID-compliant, queryable storage.

**2. Two fundamentally different workloads must run on the same data.** The startup needs low-latency, consistent reads for fraud detection on payments — this requires ACID semantics and strong consistency. It simultaneously needs high-throughput batch reads for training an ETA prediction model across months of GPS history — this needs cheap, scalable storage. A Lakehouse serves both from the same physical layer, eliminating the cost and complexity of syncing a separate warehouse and data lake.

**3. A fast-growing startup will continuously change its schemas.** New GPS fields, additional review attributes, revised menu structures — a warehouse requires expensive ALTER TABLE migrations for every change. Delta Lake and Iceberg support schema evolution natively: columns can be added, backfilled, or renamed without breaking existing queries or requiring ETL pipeline rewrites, which is critical when the data model is changing weekly.

In practice, the implementation would use S3 or GCS as object storage, Delta Lake or Iceberg as the table format, Spark or DuckDB for batch processing, and a serving layer such as Databricks SQL or Trino for BI queries.
