# Performance and scaling #

Early tests show an average 78,000 records per host per day. Disk space is
consumed at a rate of 30MB per host per day.

Expect the entries table in the database to hold millions of rows. The table has good indexing, and queries are limited to returning a sane number of rows (configurable in the conf file). Culling historical data will be required. There is an app for that ;)

Run the prune command in the script directory. It will delete records older than the number of days configured in DeltaR.conf (which you can change).

```
/opt/delta_reporting/app/script/prune
```
_Backup your data before attempting any deletes_.

The table data is numerous but small. Disk space should be less of a problem than query time as your data grows.

