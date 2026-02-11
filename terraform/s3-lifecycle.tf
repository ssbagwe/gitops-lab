# Practice S3 bucket with lifecycle policies

# Logging bucket for access logs
resource "aws_s3_bucket" "logs" {
  bucket = "platform-lab-app-data-logs"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
    Purpose     = "Access logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "cleanup-old-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_sns_topic" "logs_events" {
  name              = "s3-logs-events"
  kms_master_key_id = aws_kms_key.s3.id

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_policy" "logs_events" {
  arn = aws_sns_topic.logs_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.logs_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.logs.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "logs" {
  bucket = aws_s3_bucket.logs.id

  topic {
    topic_arn = aws_sns_topic.logs_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.logs_events]
}

# Replica bucket for logs
resource "aws_s3_bucket" "logs_replica" {
  provider = aws.replica
  bucket   = "platform-lab-app-data-logs-replica"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
    Purpose     = "Logs replication destination"
  }
}

resource "aws_s3_bucket_versioning" "logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.logs_replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.logs_replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.logs_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.logs_replica.id

  rule {
    id     = "cleanup-old-replica-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 730 # 2 years
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.logs_replica.id

  target_bucket = aws_s3_bucket.logs_replica.id
  target_prefix = "access-logs/"
}

resource "aws_sns_topic" "logs_replica_events" {
  provider          = aws.replica
  name              = "s3-logs-replica-events"
  kms_master_key_id = aws_kms_key.s3.id

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_policy" "logs_replica_events" {
  provider = aws.replica
  arn      = aws_sns_topic.logs_replica_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.logs_replica_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.logs_replica.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "logs_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.logs_replica.id

  topic {
    topic_arn = aws_sns_topic.logs_replica_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.logs_replica_events]
}

# IAM role for logs replication
resource "aws_iam_role" "logs_replication" {
  name = "s3-logs-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "logs_replication" {
  role = aws_iam_role.logs_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.logs.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.logs_replica.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  role   = aws_iam_role.logs_replication.arn

  rule {
    id     = "replicate-logs"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.logs_replica.arn
      storage_class = "GLACIER"
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

resource "aws_s3_bucket" "app_data" {
  bucket = "platform-lab-app-data"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# KMS key for S3 encryption
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow replication roles to use the key"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.replication.arn,
            aws_iam_role.logs_replication.arn
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

resource "aws_kms_alias" "s3" {
  name          = "alias/s3-app-data"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SNS topic for S3 event notifications
resource "aws_sns_topic" "s3_events" {
  name              = "s3-app-data-events"
  kms_master_key_id = aws_kms_key.s3.id

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_policy" "s3_events" {
  arn = aws_sns_topic.s3_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.s3_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.app_data.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.s3_events]
}

# Cross-region replication destination bucket
resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "platform-lab-app-data-replica"

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
    Purpose     = "Replication destination"
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  rule {
    id     = "replica-lifecycle"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 730 # 2 years
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  target_bucket = aws_s3_bucket.logs_replica.id
  target_prefix = "replica-access-logs/"
}

resource "aws_sns_topic" "replica_events" {
  provider          = aws.replica
  name              = "s3-replica-events"
  kms_master_key_id = aws_kms_key.s3.id

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_policy" "replica_events" {
  provider = aws.replica
  arn      = aws_sns_topic.replica_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.replica_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.replica.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  topic {
    topic_arn = aws_sns_topic.replica_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.replica_events]
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "replication" {
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.app_data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.app_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.replica.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.app_data]
}

resource "aws_s3_bucket_lifecycle_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  # Rule 1: Transition logs to cheaper storage, then delete
  rule {
    id     = "logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Rule 2: Clean up incomplete multipart uploads
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Rule 3: Archive old backups
  rule {
    id     = "backup-archive"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    transition {
      days          = 7
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years for compliance
    }
  }
}

# DynamoDB table for state locking practice
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.s3.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Purpose = "Terraform state locking"
  }
}

# Outputs
output "bucket_name" {
  value = aws_s3_bucket.app_data.id
}

output "bucket_arn" {
  value = aws_s3_bucket.app_data.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
