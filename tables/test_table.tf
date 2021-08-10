#terraform file 
resource "aws_s3_bucket_object" "bucket_object_ccp" {
  key                    = "processed/test_table/"
  bucket                 = var.glue_bucket_id
}

resource "aws_glue_catalog_table" "aws_glue_catalog_test_table" {  
  name = "test_table"
  database_name = var.glue_database_name 

  parameters = {
    useGlueParquetWriter = true
    classification = "parquet"
  }

  partition_keys {
    name = "year"
    type = "int"
  }

  partition_keys {
    name = "month"
    type = "int"
  }

  partition_keys {
    name = "day"
    type = "int"
  }  
  
  storage_descriptor {
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    location      = "s3://${var.glue_bucket}/processed/test_table/"

    ser_de_info {
      name                  = "JsonSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
        "explicit.null"        = false
        "parquet.compression"  = "SNAPPY"
      }
    }
  
#test table
		columns {
			name	="field_a"
			type	="string"
		}
	}
}
