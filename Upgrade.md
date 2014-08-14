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

```
GRANT SELECT ON $agent_table, $promise_counts, $inventory_table TO deltar_ro;
GRANT ALL ON $agent_table, $promise_counts, $inventory_table TO deltar_rw;
```

See DeltaR.conf for the values of the variables in the above statements.
