# Proposed use case for glue on localstack

## AWS resources
* dynamodb
* glue
  * data catalog
  * tables (parquet formatted)
* s3 - store data
* aethna - to query data in a glue table

A pyspark script is run via a glue job, the script pulls data from a dynamodb table and writes the data to a s3 bucket whilst updating the meta data in the data catalog see file etl.py of what we are trying to achieve via the glue job

The glue functionality needed would be
- create data catalog
- create table
