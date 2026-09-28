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
