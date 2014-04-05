-- psql -U postgres -w -h localhost < testsql.sql 
\c delta_reporting;

-- count any classes for now - 24 hours and -24 to -48 hours. 
/*
SELECT 
( SELECT COUNT( DISTINCT ip_address ) FROM agent_log WHERE class = 'any'
	AND timestamp > ( now() - interval '1440' minute )) AS class_today,
( SELECT COUNT( DISTINCT ip_address ) FROM agent_log WHERE class = 'any'
	AND timestamp < ( now() - interval '1440' minute ) AND Timestamp > ( now() - interval '2880' minute )) AS class_yesterday
;
*/

-- list hosts that checked in 24 to 48 hours ago but no within the past 24 hours. 
/*
SELECT DISTINCT ip_address AS missing_ip_addresses FROM agent_log WHERE class = 'any'
	AND timestamp < ( now() - interval '24' hour ) AND Timestamp > ( now() - interval '48' hour )
EXCEPT
SELECT DISTINCT ip_address FROM agent_log WHERE class = 'any'
   AND timestamp > ( now() - interval '24' hour )
;
*/

-- alternate inventory queries 

-- does not work  
/*
SELECT 
( SELECT COUNT( DISTINCT ip_address ) FROM agent_log WHERE class = 'any'
	AND timestamp > ( now() - interval '1440' minute ) ) AS any,

( SELECT COUNT( DISTINCT ip_address ) FROM agent_log WHERE class like 'debian%'
	AND timestamp > ( now() - interval '1440' minute ) GROUP BY class ) AS debian
;
*/


/*
explain analyze -- faster
SELECT class,COUNT( class )
FROM(
   SELECT class,ip_address FROM agent_log
	WHERE timestamp > ( now() - interval '1440' minute )
	AND ( lower(class) LIKE lower('am_policy_hub') ESCAPE '!' OR lower(class) LIKE lower('any') ESCAPE '!' OR lower(class) LIKE lower('centos%') ESCAPE '!' OR lower(class) LIKE lower('community%') ESCAPE '!' OR lower(class) LIKE lower('debian%') ESCAPE '!' OR lower(class) LIKE lower('enterprise%') ESCAPE '!' OR lower(class) LIKE lower('fedora%') ESCAPE '!' OR lower(class) LIKE lower('ipv4_%') ESCAPE '!' OR lower(class) LIKE lower('linux%') ESCAPE '!' OR lower(class) LIKE lower('policy_server') ESCAPE '!' OR lower(class) LIKE lower('pure_%') ESCAPE '!' OR lower(class) LIKE lower('redhat%') ESCAPE '!' OR lower(class) LIKE lower('solaris%') ESCAPE '!' OR lower(class) LIKE lower('sun4%') ESCAPE '!' OR lower(class) LIKE lower('suse%') ESCAPE '!' OR lower(class) LIKE lower('ubuntu%') ESCAPE '!' OR lower(class) LIKE lower('virt_%') ESCAPE '!' OR lower(class) LIKE lower('vmware%') ESCAPE '!' OR lower(class) LIKE lower('xen%') ESCAPE '!' OR lower(class) LIKE lower('zone_%') ESCAPE '!')
	GROUP BY class,ip_address
				)
AS class_count
GROUP BY class
;

explain analyze  -- slower
   SELECT class,COUNT ( DISTINCT ip_address ) FROM agent_log
	WHERE timestamp > ( now() - interval '1440' minute )

	AND ( lower(class) LIKE lower('am_policy_hub') ESCAPE '!' OR lower(class) LIKE lower('any') ESCAPE '!' OR lower(class) LIKE lower('centos%') ESCAPE '!' OR lower(class) LIKE lower('community%') ESCAPE '!' OR lower(class) LIKE lower('debian%') ESCAPE '!' OR lower(class) LIKE lower('enterprise%') ESCAPE '!' OR lower(class) LIKE lower('fedora%') ESCAPE '!' OR lower(class) LIKE lower('ipv4_%') ESCAPE '!' OR lower(class) LIKE lower('linux%') ESCAPE '!' OR lower(class) LIKE lower('policy_server') ESCAPE '!' OR lower(class) LIKE lower('pure_%') ESCAPE '!' OR lower(class) LIKE lower('redhat%') ESCAPE '!' OR lower(class) LIKE lower('solaris%') ESCAPE '!' OR lower(class) LIKE lower('sun4%') ESCAPE '!' OR lower(class) LIKE lower('suse%') ESCAPE '!' OR lower(class) LIKE lower('ubuntu%') ESCAPE '!' OR lower(class) LIKE lower('virt_%') ESCAPE '!' OR lower(class) LIKE lower('vmware%') ESCAPE '!' OR lower(class) LIKE lower('xen%') ESCAPE '!' OR lower(class) LIKE lower('zone_%') ESCAPE '!')
	GROUP BY class
;
*/

-- show host with the most repaired or failed in the past 24 hours.
/*
SELECT promiser,promisee,promise_handle,promise_outcome,timestamp,hostname,ip_address,policy_server
FROM(
   SELECT promiser,promisee,promise_handle,promise_outcome,timestamp,hostname,ip_address,policy_server
*/

-- INSERT INTO inventory_table ( class ) VALUES ( 'cfengine_3%' );

-- get random sample
/*
CREATE TEMPORARY TABLE agent_log_sample 
   AS
   SELECT * FROM agent_log
	WHERE timestamp > ( now() - interval '1440' minute )
   AND NOT promise_outcome = 'empty'
   ORDER BY RANDOM()
   LIMIT 100000
   ; 
SELECT promise_outcome,count(promise_outcome) AS count
   FROM agent_log_sample
   GROUP BY promise_outcome
   ;
SELECT count( DISTINCT CONCAT (ip_address,hostname)) AS hosts
   FROM agent_log_sample
   ;
DROP TABLE agent_log_sample
   ;
*/

-- Delete not max records from a single day older x days
explain SELECT * FROM agent_log 
WHERE 
NOT IN (
   SELECT
          class,
          max(timestamp) as timestamp,
          hostname,
          ip_address,
          promise_handle,
          promiser,
          promisee,
          policy_server,
          promise_outcome
      FROM agent_log
      WHERE timestamp < now() - interval '7 days' 
      GROUP BY
          class,
          DATE_TRUNC( 'day', timestamp),
          hostname,
          ip_address,
          promise_handle,
          promiser,
          promisee,
          policy_server,
          promise_outcome
)
AND timestamp < now() - interval '7 days' 
/*
SELECT timestamp,hostname,class FROM agent_log
   WHERE timestamp IN (
      SELECT max(timestamp )
         FROM (
            SELECT timestamp,class,ip_address,hostname
               FROM agent_log
               WHERE timestamp < now() - interval '5 days'
               AND class = 'any'
               GROUP BY class,ip_address,hostname
         ) AS grouped_promises
      GROUP by DATE_TRUNC( 'day', timestamp )
   )
   ORDER BY class,timestamp
;
*/
/*
            SELECT MAX(timestamp) AS maxtime,class,ip_address,hostname
               FROM agent_log
               WHERE timestamp < now() - interval '5 days'
               AND class = 'any'
               GROUP BY class,ip_address,hostname
               LIMIT 1000;
*/
-- GROUP BY promiser,promisee,promise_handle,promise_outcome,ip_address,hostname,timestamp,Day

-- Purge old data
/*
DELETE FROM agent_log WHERE timestamp < now() - interval '7 days';
vacuum agent_log;
REINDEX TABLE agent_log;
*/

-- Count all records
-- SELECT count(*) FROM agent_log WHERE timestamp > now() - interval '7 days'
