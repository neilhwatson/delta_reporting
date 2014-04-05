# Performance and scaling #

Early tests show an average 78,000 records per host per day. Disk space is
consumed at a rate of 30MB per host per day.

Expect the entries table in the database to hold millions of rows. The table has good indexing, and queries are limited to returning a sane number of rows (configurable in the conf file). Culling historical data will be required at some point. Example:

```
DELETE from agent_log WHERE time_stamp < now() - interval '30 days'
vacuum agent_log
REINDEX TABLE agent_log;
```
_Backup your data before attempting any deletes_.

The table data is numerous but small. Disk space should be less of a problem than query time as your data grows.

