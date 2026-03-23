# Part1-RDMS_Normalization

## Anomaly Analysis

The `orders_flat.csv` file stores all data — customers, products, sales reps, and orders — in a single denormalized table. This structure introduces the following anomalies.

---

### Insert Anomaly

**Definition:** An insert anomaly occurs when certain data cannot be added to the database without the existence of other, unrelated data.

**Example from the data:**

A new sales representative cannot be recorded in the system unless they have at least one order associated with them. All sales rep information (`sales_rep_id`, `sales_rep_name`, `sales_rep_email`, `office_address`) exists only as columns within order rows. There is no way to insert a new rep — say, `SR04, Meera Pillai, meera@corp.com` — without simultaneously creating a dummy or placeholder order.

**Affected columns:** `sales_rep_id`, `sales_rep_name`, `sales_rep_email`, `office_address`

**Illustration:** If SR04 is hired and assigned a region but has not yet handled any orders, they cannot exist anywhere in this table.

---

### Update Anomaly

**Definition:** An update anomaly occurs when the same real-world fact is stored redundantly across multiple rows, so updating it in one place leaves other rows inconsistent.

**Example from the data:**

Sales rep `SR01` (Deepak Joshi) has the office address recorded in two different forms across the table:

| Row (order_id) | `office_address` value |
|---|---|
| ORD1114, ORD1002, ORD1091, ... (majority of SR01 rows) | `"Mumbai HQ, Nariman Point, Mumbai - 400021"` |
| ORD1180, ORD1174, ORD1179, ORD1171, ORD1175, ORD1176 | `"Mumbai HQ, Nariman Pt, Mumbai - 400021"` |

The address for SR01 has already diverged — `"Nariman Point"` vs `"Nariman Pt"` — across different rows. If the office address genuinely changes, every row belonging to SR01 must be updated individually. Missing even one row leaves the database in an inconsistent state.

**Affected rows (sample):** ORD1180 (row 39), ORD1174 (row 154), ORD1179 (row 156), ORD1171 (row 160), ORD1175 (row 172), ORD1176 (row 182)  
**Affected columns:** `office_address` (for `sales_rep_id = SR01`)

---

### Delete Anomaly

**Definition:** A delete anomaly occurs when deleting a record causes the unintended loss of other, unrelated information.

**Example from the data:**

All information about customer `C007` (Arjun Nair) is stored exclusively across their order rows:

| order_id | customer_id | customer_name | customer_email | customer_city |
|---|---|---|---|---|
| ORD1098 | C007 | Arjun Nair | arjun@gmail.com | Bangalore |
| ORD1093 | C007 | Arjun Nair | arjun@gmail.com | Bangalore |
| ORD1163 | C007 | Arjun Nair | arjun@gmail.com | Bangalore |
| ORD1148 | C007 | Arjun Nair | arjun@gmail.com | Bangalore |
| ... | ... | ... | ... | ... |

If all orders placed by C007 are deleted (e.g., due to a bulk cancellation or data retention purge), every piece of information about Arjun Nair — their name, email address (`arjun@gmail.com`), and city — is permanently lost. There is no separate customer table to preserve this data.

**Affected columns:** `customer_id`, `customer_name`, `customer_email`, `customer_city`  
**Affected rows:** All rows where `customer_id = C007` (ORD1098, ORD1093, ORD1163, ORD1148, ORD1049, ORD1127, ORD1103, ORD1151, ORD1119, ORD1145, ORD1128, ORD1150, and others)



## Normalization Justification

The argument that a single flat table is "simpler" is appealing at first glance but collapses under the weight of real operational data. `orders_flat.csv` is a textbook demonstration of why.

Consider what "simple" actually costs here. SR01 (Deepak Joshi) appears across dozens of order rows, and his office address has already silently diverged into two spellings — `"Nariman Point"` in most rows and `"Nariman Pt"` in six others (ORD1180, ORD1174, ORD1175, and more). Nobody deliberately introduced that inconsistency; it crept in through normal data entry. In a normalized schema, `office_address` lives in exactly one row of `sales_reps`. You fix it once, and every query that touches SR01 instantly reflects the correction. In the flat table, you must hunt down and update every affected row manually — and one missed row means your reports are silently wrong.

The simplicity argument also breaks down at the business process level. Suppose the company hires a new sales rep, SR04, and assigns them a territory before they close their first deal. In `orders_flat`, this is impossible: there is nowhere to record SR04 because every row is an order. You either insert a fake order or maintain a separate spreadsheet alongside the database — which is precisely the kind of ad hoc workaround that normalization is designed to eliminate.

The delete anomaly makes the risk even more concrete. If Arjun Nair (C007) cancels all his orders and they are purged, the flat table permanently loses his name, email, and city. A normalized `customers` table retains his record regardless of order history, which matters for re-engagement campaigns, audit trails, and regulatory compliance.

The "over-engineering" label only makes sense when normalization is applied beyond what the data requires. Here, 3NF is not academic pedantry — it is the minimum structure needed to prevent data that already exists in this dataset from becoming untrustworthy. The flat table is not simpler; it is simpler to write initially and more expensive to maintain forever.
