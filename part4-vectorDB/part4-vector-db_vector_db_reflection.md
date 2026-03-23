# Vector Database Reflection

## Vector DB Use Case

A traditional keyword-based search would not suffice for this use case, and the gap is not a minor one — it is a fundamental mismatch between the tool and the problem.

Keyword search operates on exact or near-exact string matching. When a lawyer asks "What are the termination clauses?", a keyword system looks for documents containing the words "termination" and "clauses". It will miss a clause titled "Right to Dissolve the Agreement", a section headed "Exit Provisions", or a paragraph that reads "Either party may discontinue this contract upon 30 days' written notice" — all of which are semantically identical to the query but share no keywords with it. In a 500-page contract, this kind of paraphrasing is not the exception; it is the norm. Legal language varies enormously across firms, jurisdictions, and drafting styles.

This is precisely the problem that vector databases solve. The system would work in two stages. In the ingestion stage, the contract is chunked into overlapping passages — perhaps 200–300 words each — and each chunk is encoded into a high-dimensional embedding vector using a model such as `all-MiniLM-L6-v2` or a domain-fine-tuned legal model like `legal-bert`. These vectors are stored in a vector database such as Pinecone, Weaviate, or pgvector. In the retrieval stage, when a lawyer types a plain-English question, that question is encoded into the same embedding space, and the database performs an approximate nearest-neighbour search — returning the chunks whose vectors are closest to the query vector, regardless of the exact words used.

The critical advantage is that semantic proximity in the embedding space captures meaning, not surface form. "Termination clause" and "right to dissolve" land near each other in vector space because the model has learned their contextual equivalence from billions of training examples. Keyword search has no such mechanism.

The remaining challenge is that vector retrieval returns relevant passages but not structured answers. In practice, the retrieved chunks would be passed to a language model (a retrieval-augmented generation pipeline) to synthesise a precise, cited answer — combining the recall strength of vector search with the reasoning ability of a generative model.
