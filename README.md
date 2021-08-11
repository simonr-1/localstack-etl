# Proposed use case for glue on localstack

## AWS resources
* dynamodb
* glue
  * data catalog
  * tables (parquet formatted)
* s3 - store data
* athena - to query data in a glue table

A pyspark script is run via a glue job, the script pulls data from a dynamodb table and writes the data to a s3 bucket whilst updating the meta data in the data catalog see file etl.py of what we are trying to achieve via the glue job

The glue functionality needed would be
- create data catalog
- create table

## Steps to run the example
1. bring up localstack with the following command `SERVICES=dynamodb,s3,ec2,glue,sts,iam DEBUG=1 LS_LOG=trace AWS_ACCESS_KEY_ID=test AWS_SECRET_KEY=test DEFAULT_REGION=us-east-1 localstack start`
2. run the command `terraform init`
3. run the command `terraform apply -auto-approve` this will create the neccessary aws resources
4. run the command `./run.sh`
