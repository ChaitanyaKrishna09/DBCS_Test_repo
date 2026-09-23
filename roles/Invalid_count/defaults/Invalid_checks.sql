spool invalid_objects_before.log
set linesize 2000
set pagesize 2000
col OBJECT_NAME format a40
col OWNER format a40
col OBJECT_TYPE format a20
Select count(*) from cdb_objects where status='INVALID';
SELECT OWNER, COUNT(*) FROM CDB_OBJECTS WHERE STATUS = 'INVALID' GROUP BY OWNER;
select CON_ID,count(*) from cdb_objects where status='INVALID' group by CON_ID;
select owner, object_name, object_type,status from cdb_objects where status='INVALID';
select CON_ID, owner, object_name, object_type,status from cdb_objects where status='INVALID' and owner='SYS';
select CON_ID, owner, object_name, object_type,status from cdb_objects where status='INVALID' and owner='SYSTEM';
spool off
