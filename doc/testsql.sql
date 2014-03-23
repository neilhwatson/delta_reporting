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
