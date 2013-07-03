@ECHO OFF
REM Very basic script to echo VMware alarm environment variables to a
REM local file. It will write over previous alarms of the same name,
REM really it's only use is to quickly check the environemnt variables
REM that are associated with a particular alarm.

SET VMWARE_ALARM > .\%VMWARE_ALARM_NAME%.txt
