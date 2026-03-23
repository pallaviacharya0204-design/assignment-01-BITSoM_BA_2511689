# RDBMS vs NoSQL

## Database Recommendation

**Recommendation: MySQL for the core patient management system.**

Healthcare is one of the few domains where the cost of data being wrong is measured in patient safety, not just business inconvenience. A patient's medication record, allergy list, or surgical history must be exactly correct — not eventually correct. This rules out BASE systems as the primary store. MySQL's ACID guarantees ensure that if a transaction writing a prescription and deducting a drug inventory count is interrupted halfway, the database rolls back to a consistent state rather than committing half the work. No equivalent safety net exists in a BASE-compliant store.

The CAP theorem framing reinforces this. MongoDB, under a network partition, will typically favour Availability over Consistency (AP). MySQL, configured with synchronous replication, favours Consistency and Partition tolerance (CP). For patient records, reading stale data — say, a nurse seeing an outdated allergy list because a replica hasn't caught up — is clinically dangerous. The right trade-off here is CP: briefly unavailable is survivable; silently inconsistent is not.

There is also a structural argument. Patient data is highly relational: patients link to appointments, appointments to doctors, doctors to departments, encounters to prescriptions and lab results. This web of relationships is exactly what a relational model and JOIN-based queries are optimised for. A document store would either denormalise this (reintroducing anomalies) or simulate joins in application code.

**Would the answer change for a fraud detection module? Yes — partially.**

Fraud detection has a fundamentally different read/write profile: it ingests high-velocity transaction streams, runs graph and pattern queries across large volumes of semi-structured event data, and tolerates brief inconsistency in real-time scoring. A document store like MongoDB (or better yet, a graph database like Neo4j for relationship traversal, or Apache Kafka + a time-series store for event streaming) suits this module well.

The right architecture is polyglot: MySQL as the authoritative, ACID-compliant source of truth for patient records, with MongoDB or a streaming store as the fraud detection layer consuming events from it — not replacing it.
