# Performance and scaling #

Early tests show an average 78,000 records per host per day. Disk space is
consumed at a rate of 30MB per host per day.

Expect the entries table in the database to hold millions of rows. The table has good indexing, and queries are limited to returning a sane number of rows (configurable in the conf file). Culling and aggregating historical data will be required. There is an app for that ;)

Run the prune command in the script directory. It will delete records older than the number of days configured in DeltaR.conf (which you can change).

```
/opt/delta_reporting/app/script/prune
```

Run the reduce command in the script directory will keep the highest timestamp of a promise record for a day and delete the rest from that day. This affects all promises older than the age defined in DeltarR.conf.

```
/opt/delta_reporting/app/script/reduce
```

These jobs may be long running, so it's best to use cron rather than a cf-agent command promise.

_Backup your data before attempting any deletes_.

The table data is numerous but small. Disk space should be less of a problem than query time as your data grows.

## License ##

Delta Reporting is a central server compliance log that uses CFEngine.

Copyright (C) 2013 Evolve Thinking http://evolvethinking.com

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
