# Setup and reproduction

How to rebuild any project in this repository from the raw source files.

Every project is designed to be reproducible from scratch: the schema, the load
scripts and the verification checks are all committed, and only the raw data is
missing because it is large and freely available from its original source.

---

## Prerequisites

- MySQL Server 8.0 or later
- MySQL Workbench, or any client that supports `LOAD DATA LOCAL INFILE`
- Git

---

## 1. Clone and place the data

```bash
git clone https://github.com/sruthi-swathandran/sql-portfolio.git
```

Download the source archive using the link in the relevant project README and
extract the CSVs into that project's `data/` folder. That folder is gitignored,
so it will be empty after cloning.

The load scripts expect the files at, for example:

```
sql-portfolio/01-maven-fuzzy-factory/data/website_sessions.csv
```

---

## 2. Enable local file loading

`LOAD DATA LOCAL INFILE` is disabled by default and has to be enabled in **two
separate places**. Enabling only one gives `Error 3948: Loading local data is
disabled`, which is the most common thing to get stuck on.

**Server side**, run once:

```sql
SET GLOBAL local_infile = 1;
```

**Client side**, in MySQL Workbench:

1. On the home screen, right-click your connection and choose Edit Connection
2. Advanced tab
3. In the "Others:" box add `OPT_LOCAL_INFILE=1`
4. Close the connection and reopen it

The reconnect matters. The client setting is read when the connection opens, so
an existing session keeps the old value and the error persists even though both
settings now look correct.

---

## 3. Update the file paths

`schema/02_load_data.sql` contains absolute paths. If the repository is not at
`D:/Projects`, edit them.

Use forward slashes even on Windows. Backslash is SQL's escape character, so
`D:\Projects` will fail in ways that are not obvious from the error.

---

## 4. Run the scripts in order

From `schema/`:

| Script | Purpose |
|---|---|
| `01_create_tables.sql` | Creates the database and tables with keys and types |
| `02_load_data.sql` | Loads the CSVs, parent tables first so foreign keys hold |
| `03_verify_load.sql` | Checks the load actually worked |
| `04_add_indexes.sql` | Adds indexes, after loading rather than before |

Indexes come last on purpose. Maintaining them during a bulk insert slows the
load and gains nothing, since nothing queries the table until it is populated.

Then run the files in `analysis/` in numerical order. Each is independent and
answers one business question.

---

## 5. Verify before analysing

Run `03_verify_load.sql` and check every result against the expected values
stated above each query in that file.

This step is not optional. A load can complete without raising a single error and
still be wrong, and all three failure modes below did occur while building
project 1.

---

## Troubleshooting

### Error 3948: Loading local data is disabled

Both settings from step 2 are required, and the connection must be reopened after
changing the client one. Confirm the server side with:

```sql
SHOW GLOBAL VARIABLES LIKE 'local_infile';
```

### Error 2: File not found

The CSVs were not extracted, or the path in `02_load_data.sql` does not match
where they actually are. Check the exact filename too, since some archives nest
the files inside a subfolder.

### The load reports 0 rows affected and no error

Line endings. Most of these files use Windows CRLF, but not all of them do, and
`LINES TERMINATED BY '\r\n'` applied to an LF file matches nothing and loads
nothing without complaining.

In the Maven Fuzzy Factory data, `website_pageviews.csv` is the exception and
needs `'\n'` while the other five need `'\r\n'`. The load script notes this.

### Text columns contain a trailing invisible character

The reverse of the problem above: `'\n'` applied to a CRLF file leaves a carriage
return on the last column of every row. Nothing errors, joins silently fail to
match, and string comparisons behave strangely.

Check with:

```sql
SELECT product_name, CHAR_LENGTH(product_name) FROM products;
```

If the lengths are one character longer than the visible text, this is why.

### Columns contain the text "NULL" instead of real nulls

Some source files write missing values as the four-character string `NULL`.
Loaded naively, that text goes straight into the column, so `IS NULL` finds
nothing and `COUNT` counts everything.

The fix is to read the column into a variable and convert it:

```sql
(website_session_id, created_at, @utm_source)
SET utm_source = NULLIF(@utm_source, 'NULL')
```

Verify with:

```sql
SELECT SUM(utm_source = 'NULL') AS literal_text,
       SUM(utm_source IS NULL)  AS real_nulls
FROM website_sessions;
```

The first should be zero.
