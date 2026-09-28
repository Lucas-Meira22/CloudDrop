resource "aws_s3_bucket" "app" {
  bucket_prefix = "${var.project_name}-files-"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

# The app's access to its own bucket, and nothing else
data "aws_iam_policy_document" "s3_app" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.app.arn]
  }

  statement {
    sid       = "ReadWriteObjects"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.app.arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_app" {
  name   = "${var.project_name}-s3-app"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.s3_app.json
}


# Nothing in this bucket can ever be made public
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cleans up automatically so storage can't grow forever
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "expire-after-30-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.app]
}