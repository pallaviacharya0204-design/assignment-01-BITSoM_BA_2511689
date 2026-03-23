# ETL Notes

## ETL Decisions

The raw file `retail_transactions.csv` contained 300 rows and three categories
of quality issues, all identified by profiling the data before any loading
began. Each issue required a deliberate transformation decision before the data
could be loaded into the star schema without ambiguity.

---

### Decision 1 — Normalise Three Conflicting Date Formats

**Problem:**
The `date` column in the source file mixed three different formats across rows
with no consistent pattern:

| Format | Example | Rows affected |
|---|---|---|
| `YYYY-MM-DD` (ISO 8601) | `2023-08-09` | ~40% of rows |
| `DD-MM-YYYY` (hyphen) | `12-12-2023` | ~30% of rows |
| `DD/MM/YYYY` (slash) | `29/08/2023` | ~30% of rows |

Loading these directly into a `DATE` column would either fail outright or, worse,
silently mis-parse some values. For example, a database that assumes `MM-DD-YYYY`
would read `12-12-2023` correctly by accident but interpret `05-08-2023` as
May 8th instead of August 5th — producing wrong results with no error raised.

**Resolution:**
Before insertion, every date string was parsed by trying all three format
patterns in order (`YYYY-MM-DD` first, then `DD-MM-YYYY`, then `DD/MM/YYYY`)
using Python's `datetime.strptime`. The result was re-emitted as a canonical
ISO 8601 string (`YYYY-MM-DD`), which was then stored in `dim_date.full_date`
and converted to the integer surrogate key `date_key` (format `YYYYMMDD`).
Using an integer key makes date range predicates faster (integer comparison vs
string comparison) and human-readable without requiring a join back to
`dim_date`. Any row whose date could not be parsed by any of the three patterns
was flagged and excluded, ensuring no malformed dates enter the warehouse.

---

### Decision 2 — Consolidate Four Category Spellings into Three Canonical Values

**Problem:**
The `category` column contained four distinct string values that represented
only three real-world categories:

| Raw value | Count | Issue |
|---|---|---|
| `Electronics` | 60 | Correct — canonical |
| `electronics` | 41 | Wrong casing |
| `Groceries` | 40 | Correct — canonical |
| `Grocery` | 87 | Singular vs plural; same meaning |
| `Clothing` | 72 | Correct — canonical |

Had these been loaded as-is, `GROUP BY category` queries would have returned
five groups instead of three. A report showing "Electronics vs electronics" as
separate categories would be meaningless and misleading. The `Grocery`/`Groceries`
split was particularly dangerous because it would cause `Grocery` products
(87 rows, the largest single variant) to appear as a fourth category in
aggregations, silently under-reporting the true Groceries total by 68%.

**Resolution:**
A two-step normalisation was applied before loading `dim_product`:
1. **Case normalisation** — every value was title-cased (`str.title()` in
   Python), converting `"electronics"` → `"Electronics"`.
2. **Synonym merge** — `"Grocery"` was mapped to `"Groceries"` as the canonical
   plural form, matching the majority spelling and the more linguistically
   standard label for a product category.

The three resulting canonical values — `Electronics`, `Clothing`, `Groceries` —
were stored in `dim_product.category` and enforced consistently across all
16 product rows. No category value appears more than once in the dimension,
making `GROUP BY p.category` unambiguous for all downstream queries.

---

### Decision 3 — Impute Missing Store Cities from Store Name

**Problem:**
19 rows (6.3% of the dataset) had an empty string in the `store_city` column.
The affected rows were spread across all five stores:

| Store name | Rows with empty city |
|---|---|
| Pune FC Road | 7 |
| Delhi South | 5 |
| Chennai Anna | 4 |
| Mumbai Central | 3 |
| Bangalore MG | 0 |

Dropping these 19 rows entirely would have been the safest option from a
purity standpoint, but it would have introduced survivorship bias — entire
stores would be under-represented in revenue totals by a statistically
non-trivial amount. Leaving city as NULL would cause those rows to be silently
excluded from any `WHERE city = '...'` filter or `GROUP BY city` aggregation,
producing quietly incorrect regional reports.

**Resolution:**
The source data has a deterministic, unambiguous relationship between store
name and city: each of the five store names maps to exactly one city, and no
city name is shared by more than one store. This was verified by cross-checking
all rows where both store_name and store_city were populated — no store appeared
in more than one city.

Given this 1-to-1 mapping, the missing city was imputed using a lookup
dictionary (`store_name → city`) applied at load time:
`"Bangalore MG" → "Bangalore"`, `"Chennai Anna" → "Chennai"`, etc. This is a
sound imputation because the city is a fixed property of the store (a store
does not move), not a customer-reported or variable field. The imputed city
was loaded into `dim_store.city`; since each store appears only once in the
dimension table, the fix also applies automatically to all 19 affected fact
rows via the foreign key join.
