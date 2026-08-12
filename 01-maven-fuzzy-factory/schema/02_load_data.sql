/* =============================================================
   Maven Fuzzy Factory - Data Load
   MySQL 8.0

   Loads six CSV files into the tables created by
   01_create_tables.sql. Run that script first.

   PREREQUISITES
   -------------
   1. Place the six CSVs in this project's data/ folder.

   2. Enable local file loading. Required in TWO places:

      Server:  SET GLOBAL local_infile = 1;

      Client:  Workbench home screen > right-click the connection
               > Edit Connection > Advanced tab > "Others:" box,
               add OPT_LOCAL_INFILE=1, then reopen the connection.

      Missing either gives: "Loading local data is disabled".

   3. Update the file paths below if the repository is not at
      D:/Projects. Use forward slashes even on Windows -
      backslash is SQL's escape character.

   NOTES
   -----
   Source files use Windows line endings (\r\n). Loading them as
   '\n' leaves a trailing carriage return on the last column of
   every row, which does not error but silently corrupts the data.

   Tables are loaded parent-first so the foreign key constraints
   are satisfied at every step.
   ============================================================= */

use mavenfuzzyfactory;
