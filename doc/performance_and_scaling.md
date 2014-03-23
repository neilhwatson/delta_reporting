# Performance and scaling #

A huge number of records will accumulate in the database. Delta Reporting stores the history of all classes and most promises. Consider a conservative estimate of 100 classes and promises per host, per run.

`
100 entries * 12 runs/hr * 24 hr/day = 28,800 entries/hr
`

28,800 entries per hour, per 100 classes and promises, per host. Expect the entries table in the database to hold millions of rows. The table has good indexing, and queries are limited to returning a sane number of rows (configurable in the conf file). Culling historical data will be required at some point. Example:

`
DELETE from agent_log WHERE time_stamp < now() - interval '30 days'
vacuum agent_log
`
_Backup your data before attempting any deletes_.

The table data is numerous but small. Disk space should be less of a problem than query time as your data grows.

