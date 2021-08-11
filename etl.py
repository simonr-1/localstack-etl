import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col
from datetime import datetime
from pyspark.sql.functions import udf
from pyspark.sql.types import IntegerType

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
## @type: DataSource
## @args: [connection_type="dynamodb", connection_options={ "dynamodb.input.tableName": "test_table", "dynamodb.throughput.read.percent": "1.0" }, transformation_ctx = "datasource0"]
## @return: datasource0
## @inputs: []
datasource0 = glueContext.create_dynamic_frame.from_options(connection_type="dynamodb", connection_options={ "dynamodb.input.tableName": "test_table", "dynamodb.throughput.read.percent": "1.0" }, transformation_ctx = "datasource0")

#todo filter data based on the timestamp, it should check the last timestamp stored against a table in a s3 file

datasource0 = DropFields.apply( frame = datasource0, paths = ["lastDT#Seq"], transformation_ctx = "dropfields")
datasource0.printSchema()
column_mapping = [("timestamp","long","timestamp","long"),("field_a","string","field_b","string")]

datasource0 = ApplyMapping.apply(frame = datasource0, mappings = column_mapping, transformation_ctx="applymapping1")
datasource0 = ResolveChoice.apply(frame = datasource0, choice = "make_struct", transformation_ctx = "resolvechoice4")

datasource0.printSchema()

def get_date_from_timestamp(timestamp, date_type):
  #timestamp comes in nanoseconds
  timestamp = timestamp / 1000000
  date_obj = datetime.fromtimestamp(timestamp/1000.0)
  
  if( date_type == 'year' ):
    return date_obj.year
  elif( date_type == 'month' ):
    return date_obj.month
  elif( date_type == 'day' ):
    return date_obj.day
  elif( date_type == 'hour' ):
    return date_obj.hour
  else:
    return 0

def get_year_from_timestamp(timestamp):
  return get_date_from_timestamp(timestamp,"year")

def get_month_from_timestamp(timestamp):
  return get_date_from_timestamp(timestamp,"month")

def get_day_from_timestamp(timestamp):
  return get_date_from_timestamp(timestamp,"day")

def get_hour_from_timestamp(timestamp):
  return get_date_from_timestamp(timestamp,"hour")  


get_year = udf(lambda x,: get_year_from_timestamp(x), IntegerType())
spark.udf.register("get_year", get_year)

get_day = udf(lambda x,: get_day_from_timestamp(x), IntegerType())
spark.udf.register("get_day", get_day)

get_month = udf(lambda x,: get_month_from_timestamp(x), IntegerType())
spark.udf.register("get_month", get_month)

get_hour = udf(lambda x,: get_hour_from_timestamp(x), IntegerType())
spark.udf.register("get_hour", get_hour)
df = datasource0.toDF()

df = df.withColumn("year",get_year(col("timestamp")))
df = df.withColumn("month",get_month(col("timestamp")))
df = df.withColumn("day",get_day(col("timestamp")))


#find the unqiue partitions in this dataset, we need to find this out first in order to determine the number of files we generate
partitions = df.select('year','month','day').distinct().collect()

for row in partitions:
  partition_filter = "year = {} and month = {} and day = {}".format(row['year'],row['month'],row['day'])
  partition = df.filter(partition_filter)
  num_of_records = partition.count()
  print(partition.count())
  dyanmic_f = DynamicFrame.fromDF(partition, glueContext,'test')
  optimal_num_partitions = int(num_of_records/100000)
  if(optimal_num_partitions < 1):
    optimal_num_partitions = 1
  dyanmic_f = dyanmic_f.coalesce(optimal_num_partitions)
  print(dyanmic_f.getNumPartitions())
  sink = glueContext.getSink(connection_type="s3", path="s3://my-bucket/processed/test_table",
    enableUpdateCatalog=True, updateBehavior="UPDATE_IN_DATABASE",
    partitionKeys=["year", "month","day"])
  sink.setFormat("glueparquet")
  sink.setCatalogInfo(catalogDatabase="test_catalog", catalogTableName="test_table")
  sink.writeFrame(dyanmic_f)

#todo store latest timestamp against a table in a json file stored in s3
job.commit()
