# Upgrading #

## Tag 2.4

Note that DeltaR.conf has changed. There are now two database users, one for read only work and the other for read write work.

```
   db_user         => "deltar_ro",
   db_pass         => "",
   db_wuser        => "deltar_rw",
   db_wpass        => "",
```

Call the users whatever you like, but note them in the config file. Also GRANT db_user SELECT only privileges and db_wuser ALL priviliges. Example:

```sql
GRANT SELECT ON $agent_table, $promise_counts, $inventory_table TO deltar_ro;
GRANT ALL ON $agent_table, $promise_counts, $inventory_table TO deltar_rw;
GRANT ALL ON SEQUENCE "agent_log_rowId_seq" TO deltar_rw;
GRANT ALL ON SEQUENCE promise_counts_rowid_seq TO deltar_rw;
GRANT ALL ON SEQUENCE "inventory_table_rowId_seq" TO deltar_rw;
ALTER TABLE agent_log OWNER TO deltar_rw;
ALTER TABLE inventory_table OWNER TO deltar_rw;
ALTER TABLE promise_counts OWNER TO deltar_rw;
ALTER SEQUENCE "agent_log_rowId_seq" OWNER TO deltar_rw;
ALTER SEQUENCE "inventory_table_rowId_seq" OWNER TO deltar_rw;
ALTER SEQUENCE "promise_counts_rowid_seq" OWNER TO deltar_rw;
```

See DeltaR.conf for the values of the variables in the above statements.
