# Hey!: https://www.writesoftwarewell.com/working-with-sqlite-in-ruby/
require "sqlite3"

db = SQLite3::Database.new("data.db")
db.execute <<~SQL
  CREATE TABLE articles(
    id INTEGER NOT NULL PRIMARY KEY,
    title TEXT,
    body TEXT
  )
SQL