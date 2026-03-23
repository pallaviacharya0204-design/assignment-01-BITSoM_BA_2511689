// =============================================================================
// mongo_queries.js
// MongoDB operations for the e-commerce product catalog.
//
// Run in the MongoDB Shell (mongosh) after connecting to your instance:
//   mongosh "mongodb://localhost:27017/ecommerce"
//   load("mongo_queries.js")
//
// Or execute line-by-line in MongoDB Compass > "MongoDB Shell" tab.
//
// All operations target the `products` collection inside the `ecommerce` db.
// =============================================================================

use("ecommerce");

// =============================================================================
// OP1: insertMany() — insert all 3 documents from sample_documents.json
// =============================================================================
//
// Inserts one document per category (Electronics, Clothing, Groceries).
// The _id values are explicit ObjectIds so they are stable and referenceable
// by the operations below. Passing { ordered: true } (the default) means
// MongoDB stops on the first duplicate-key error; useful during development.
//
// Expected result:
//   { acknowledged: true, insertedIds: { '0': ObjectId(...01), '1': ..02, '2': ..03 } }
// =============================================================================

db.products.insertMany(
  [
    // ── Document 1: Electronics ───────────────────────────────────────────────
    {
      _id: ObjectId("64b1f2a3c8e4d500123abc01"),
      sku: "ELEC-TV-00142",
      category: "Electronics",
      name: 'Sony Bravia 55" 4K OLED Smart TV',
      brand: "Sony",
      model: "XR-55A80L",
      description:
        "55-inch 4K OLED display with Cognitive Processor XR, Dolby Vision & Atmos, Google TV.",
      price: {
        amount: 139900,
        currency: "INR",
        discount_percent: 10,
        effective_price: 125910,
      },
      stock: { available: true, quantity: 34, warehouse_location: "BLR-WH2" },
      images: [
        "https://cdn.shop.example/elec/tv-00142-front.jpg",
        "https://cdn.shop.example/elec/tv-00142-side.jpg",
        "https://cdn.shop.example/elec/tv-00142-remote.jpg",
      ],
      specifications: {
        display: {
          panel_type: "OLED",
          resolution: "3840x2160",
          refresh_rate_hz: 120,
          hdr_support: ["HDR10", "Dolby Vision", "HLG"],
        },
        audio: {
          output_watts: 60,
          channels: "2.1",
          technologies: ["Dolby Atmos", "DTS:X"],
        },
        connectivity: {
          hdmi_ports: 4,
          usb_ports: 2,
          wifi: "Wi-Fi 5 (802.11ac)",
          bluetooth: "5.0",
          has_ethernet: true,
        },
        power: {
          voltage_volts: 220,
          frequency_hz: 50,
          max_consumption_watts: 180,
          standby_consumption_watts: 0.5,
        },
        dimensions: {
          without_stand_cm: { width: 122.6, height: 70.9, depth: 5.7 },
          with_stand_cm: { width: 122.6, height: 78.2, depth: 26.5 },
          weight_kg: 18.4,
        },
      },
      warranty: {
        duration_years: 2,
        type: "Manufacturer",
        covers: ["Manufacturing defects", "Panel issues"],
        excludes: ["Physical damage", "Liquid damage"],
        support_contact: "1800-103-7799",
      },
      certifications: ["BIS", "Energy Star 8.0", "RoHS"],
      in_box: [
        "TV Unit",
        "Stand",
        "Remote Control (AA batteries included)",
        "Power Cable",
        "Warranty Card",
      ],
      ratings: { average: 4.5, count: 1280 },
      tags: ["smart tv", "4k", "oled", "sony", "home theatre"],
      created_at: new Date("2024-01-15T09:00:00Z"),
      updated_at: new Date("2025-02-10T14:30:00Z"),
    },

    // ── Document 2: Clothing ──────────────────────────────────────────────────
    {
      _id: ObjectId("64b1f2a3c8e4d500123abc02"),
      sku: "CLTH-JKT-00389",
      category: "Clothing",
      name: "Roadster Men's Quilted Puffer Jacket",
      brand: "Roadster",
      description:
        "Lightweight quilted puffer jacket with zip-off hood, ideal for mild winters and travel.",
      price: {
        amount: 2999,
        currency: "INR",
        discount_percent: 40,
        effective_price: 1799,
      },
      stock: { available: true, quantity: 210, warehouse_location: "DEL-WH1" },
      images: [
        "https://cdn.shop.example/clth/jkt-00389-navy-front.jpg",
        "https://cdn.shop.example/clth/jkt-00389-navy-back.jpg",
        "https://cdn.shop.example/clth/jkt-00389-black-front.jpg",
      ],
      variants: [
        {
          color: "Navy Blue",
          color_hex: "#1B2A6B",
          sizes_available: [
            { size: "S", quantity: 18 },
            { size: "M", quantity: 42 },
            { size: "L", quantity: 35 },
            { size: "XL", quantity: 20 },
            { size: "XXL", quantity: 9 },
          ],
        },
        {
          color: "Jet Black",
          color_hex: "#0A0A0A",
          sizes_available: [
            { size: "S", quantity: 10 },
            { size: "M", quantity: 30 },
            { size: "L", quantity: 28 },
            { size: "XL", quantity: 15 },
            { size: "XXL", quantity: 3 },
          ],
        },
      ],
      specifications: {
        gender: "Men",
        fit_type: "Regular Fit",
        occasion: ["Casual", "Travel", "Outdoor"],
        fabric: {
          outer_shell: "100% Nylon (Ripstop)",
          lining: "100% Polyester",
          fill: "Recycled Polyester Fibre (200g)",
        },
        features: [
          "Zip-off detachable hood",
          "2 side zip pockets",
          "1 inner chest pocket",
          "Elasticated hem and cuffs",
          "Packable into its own pocket",
        ],
        care_instructions: [
          "Machine wash cold (30°C)",
          "Do not bleach",
          "Tumble dry low",
          "Do not dry clean",
        ],
        country_of_origin: "India",
      },
      size_guide: {
        unit: "cm",
        chart: [
          { size: "S",   chest: 91,  waist: 76,  length: 68 },
          { size: "M",   chest: 96,  waist: 81,  length: 70 },
          { size: "L",   chest: 101, waist: 86,  length: 72 },
          { size: "XL",  chest: 106, waist: 91,  length: 74 },
          { size: "XXL", chest: 116, waist: 101, length: 76 },
        ],
      },
      ratings: { average: 4.2, count: 3450 },
      tags: ["jacket", "puffer", "winter", "men", "casual"],
      created_at: new Date("2024-03-01T06:00:00Z"),
      updated_at: new Date("2025-01-20T11:15:00Z"),
    },

    // ── Document 3: Groceries ─────────────────────────────────────────────────
    {
      _id: ObjectId("64b1f2a3c8e4d500123abc03"),
      sku: "GROC-OAT-00751",
      category: "Groceries",
      name: "Quaker Oats Rolled Oats — 1 kg",
      brand: "Quaker",
      description:
        "100% whole grain rolled oats. No added sugar, preservatives, or artificial flavours. FSSAI certified.",
      price: {
        amount: 299,
        currency: "INR",
        discount_percent: 5,
        effective_price: 284,
      },
      stock: { available: true, quantity: 875, warehouse_location: "MUM-WH3" },
      images: [
        "https://cdn.shop.example/groc/oat-00751-front.jpg",
        "https://cdn.shop.example/groc/oat-00751-back.jpg",
      ],
      specifications: {
        weight: { net_weight_g: 1000, gross_weight_g: 1050 },
        packaging: "Resealable Zip-lock Pouch",
        storage_instructions:
          "Store in a cool, dry place away from direct sunlight. Refrigerate after opening.",
        shelf_life: {
          from_manufacture_months: 12,
          best_before_example: "2026-04-30",
        },
        batch_info: {
          batch_number: "QO-2025-APR-04",
          manufactured_date: "2025-04-30",
          expiry_date: "2026-04-30",
        },
      },
      nutritional_info: {
        serving_size_g: 40,
        servings_per_pack: 25,
        per_serving: {
          energy_kcal: 148,
          protein_g: 5.0,
          carbohydrates_g: 25.2,
          of_which_sugars_g: 0.5,
          dietary_fibre_g: 3.8,
          total_fat_g: 2.8,
          of_which_saturated_fat_g: 0.5,
          sodium_mg: 2,
          iron_mg: 1.8,
        },
        allergens: ["Contains Gluten (Oats)"],
        free_from: ["Nuts", "Dairy", "Soy", "Eggs"],
      },
      certifications: [
        { body: "FSSAI", licence_number: "10014022000512" },
        { body: "ISO", standard: "22000:2018" },
      ],
      dietary_flags: {
        is_vegan: true,
        is_vegetarian: true,
        is_gluten_free: false,
        is_organic: false,
        is_non_gmo: true,
      },
      ratings: { average: 4.7, count: 22100 },
      tags: ["oats", "breakfast", "healthy", "whole grain", "quaker", "high fibre"],
      created_at: new Date("2023-11-01T08:00:00Z"),
      updated_at: new Date("2025-04-30T07:45:00Z"),
    },
  ],
  { ordered: true }
);


// =============================================================================
// OP2: find() — retrieve all Electronics products with price > 20000
// =============================================================================
//
// Queries on `price.amount` (the original catalogue price before any discount)
// using dot notation to reach into the nested `price` object.
//
// Projection: returns name, brand, price, and ratings — enough to render a
// product card — while suppressing the heavy `specifications` and `images`
// arrays to keep the response lean.
//
// Why `price.amount` and not `price.effective_price`?
//   `effective_price` is a derived value (amount - discount). Querying on
//   `amount` lets buyers filter by catalogue value; a separate query on
//   `effective_price` would cover post-discount filtering.
//
// Expected result: Sony Bravia TV (price.amount = 139900) is returned;
//                  Jacket (2999) and Oats (299) are not.
// =============================================================================

db.products.find(
  {
    category: "Electronics",
    "price.amount": { $gt: 20000 },
  },
  {
    _id: 0,
    sku: 1,
    name: 1,
    brand: 1,
    "price.amount": 1,
    "price.effective_price": 1,
    "price.discount_percent": 1,
    "ratings.average": 1,
    "stock.available": 1,
  }
);


// =============================================================================
// OP3: find() — retrieve all Groceries expiring before 2025-01-01
// =============================================================================
//
// The expiry date is stored as a string ("YYYY-MM-DD") inside the nested path
// `specifications.batch_info.expiry_date`.
//
// String comparison works correctly here because the dates follow ISO-8601
// format — lexicographic order matches chronological order for YYYY-MM-DD.
// In a production system you would store expiry_date as a native ISODate for
// range queries via $lt / $gt with Date objects, e.g.:
//   "specifications.batch_info.expiry_date": { $lt: new Date("2025-01-01") }
//
// Using string comparison to match the schema as designed:
//
// Expected result: no documents returned from seed data (oats expire 2026-04-30),
//                  demonstrating the filter logic is correct — any grocery with
//                  expiry_date < "2025-01-01" would be surfaced here.
// =============================================================================

db.products.find(
  {
    category: "Groceries",
    "specifications.batch_info.expiry_date": { $lt: "2025-01-01" },
  },
  {
    _id: 0,
    sku: 1,
    name: 1,
    brand: 1,
    "specifications.batch_info.expiry_date": 1,
    "specifications.batch_info.batch_number": 1,
    "stock.quantity": 1,
  }
);


// =============================================================================
// OP4: updateOne() — add a "discount_percent" field to a specific product
// =============================================================================
//
// Targets the Clothing jacket (SKU CLTH-JKT-00389) and introduces a new
// top-level `promotional_discount` object to store a time-boxed flash sale,
// distinct from the existing `price.discount_percent` (which is the standard
// markdown).
//
// Operators used:
//   $set  — sets new fields without touching any other existing fields
//   $currentDate — records when the promotion was applied, using MongoDB's
//                  server-side clock (more reliable than application-side now())
//
// Using `{ upsert: false }` (explicit default) ensures this is a strict update
// — it will NOT silently create a new document if the SKU doesn't exist.
//
// Expected result: { acknowledged: true, matchedCount: 1, modifiedCount: 1 }
// =============================================================================

db.products.updateOne(
  { sku: "CLTH-JKT-00389" },
  {
    $set: {
      "promotional_discount": {
        discount_percent: 55,
        label: "End of Season Sale",
        valid_from: new Date("2025-03-01T00:00:00Z"),
        valid_until: new Date("2025-03-15T23:59:59Z"),
        promo_code: "EOS55",
      },
    },
    $currentDate: { updated_at: true },
  },
  { upsert: false }
);


// =============================================================================
// OP5: createIndex() — create an index on the category field
// =============================================================================
//
// WHY THIS INDEX IS IMPORTANT
// ───────────────────────────
// `category` is the primary filter used in nearly every query in this catalog:
//   - OP2 filters by category = "Electronics"
//   - OP3 filters by category = "Groceries"
//   - The storefront likely renders category landing pages (e.g., /electronics)
//
// Without an index, MongoDB performs a COLLSCAN (full collection scan) —
// reading every document to evaluate the filter. For a catalog with 100,000+
// products, this is prohibitively slow.
//
// With this index, MongoDB performs an IXSCAN — jumping directly to the
// matching subset, then fetching only those documents. Even at 1 million docs,
// a query for category = "Electronics" (say, 300k docs) scans only the
// relevant index entries rather than the full collection.
//
// COMPOUND INDEX CHOICE
// ──────────────────────
// A compound index { category: 1, "price.amount": -1 } covers the exact query
// pattern in OP2 (filter on category, then filter/sort on price) using an
// index-only scan for both predicates simultaneously — no second filtering
// pass required.
//
// The sort order on price is DESC (-1) because product listing pages
// typically default to "price: high to low".
//
// The simpler single-field index is also created below for general use.
//
// Expected result (single-field):
//   { ok: 1, createdCollectionAutomatically: false, numIndexesBefore: 1, numIndexesAfter: 2 }
// =============================================================================

// Single-field index: fast category-only lookups (e.g., /groceries page)
db.products.createIndex(
  { category: 1 },
  {
    name: "idx_category",
    background: true,   // builds without blocking reads/writes (pre-4.2 option;
                        // MongoDB 4.2+ builds all indexes in the background by default)
  }
);

// Compound index: covers OP2-style queries (category + price filter/sort)
db.products.createIndex(
  { category: 1, "price.amount": -1 },
  {
    name: "idx_category_price_desc",
    background: true,
  }
);

// Verify the index was created and inspect the query plan for OP2:
db.products.explain("executionStats").find({
  category: "Electronics",
  "price.amount": { $gt: 20000 },
});
// Look for `winningPlan.inputStage.stage === "IXSCAN"` and
// `executionStats.totalDocsExamined` being far less than totalKeysExamined
// to confirm the index is being used.
