#!/bin/bash

#awslocal s3 mb s3://test
#awslocal s3 cp etl.py s3://test/etl.py

#awslocal glue create-job --name python-job-cli --role Glue_DefaultRole --command '{"Name" : "my_python_etl", "ScriptLocation" : "s3://test/etl.py"}'
awslocal glue start-job-run --job-name python-job-cli
