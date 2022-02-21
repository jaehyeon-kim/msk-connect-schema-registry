resource "aws_s3_bucket" "data_bucket" {
  bucket = local.data_bucket_name

  tags = {
    Name = local.data_bucket_name
  }
}

resource "aws_s3_bucket_acl" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
