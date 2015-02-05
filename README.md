heka-clever-plugins
===================

Testing
-------

1. Check out [heka](https://github.com/mozilla-services/heka/) (or, at Clever, [heka-private](https://github.com/Clever/heka-private))

2. Add any new plugins or dependencies to heka's `cmake/plugin_loader.cmake`.

3. Build Heka as [described in the Heka docs](http://hekad.readthedocs.org/en/v0.6.0/installing.html).

4. Copy the modified source files of plugins you wish to test to `<hekadir>/build/heka/src/github.com/Clever`

5. Run `make test` to run all tests, or `ctest -R <test>` to run tests individually

Plugins
-------

## Decoders
### Json Decoder

Reads JSON in message payload, and writes its keys and values to the Heka message's fields.

## Encoders
### Schema Librato Encoder
### Statmetric Segment Encoder

## Filters
### InfluxDB Batch Filter

## Outputs
### Postgres Output

Writes data to a Postgres database.

```toml
[ExamplePostgresOutput]
type = "PostgresOutput"

# Insert into this table in Postgres DB
insert_table = "test_table"

# Insert fields is a space delimited list of Heka Message Fields names.
# It write those fields values in order into a INSERT INTO statement, i.e.
#   INSERT INTO "test_table" VALUES ($1 $2 $3)
# where $1 $2 $3 are values read from insert_fields
#
# `Timestamp` is a special case that reads timestamp on Heka message.
# Otherwise, fields names corresponding to Heka Message Fields.
insert_fields = "Timestamp field_a field_b"

# Database connection parameters
db_host = "localhost"
db_port = 5432
db_name = "name"
db_user = "user"
db_password = "password"
db_connection_timeout = 5
db_ssl_mode = "disable"

# Batching configuration
flush_interval = 1000 # max time before doing an insert (in milliseconds)
flush_count = 10000 # max number of messages to batch before inserting
```

### Keen Output

Sends event data to Keen.io.

