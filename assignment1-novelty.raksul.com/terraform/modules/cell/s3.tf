# ------------------------------------------------------------------------------
# S3 Bucket
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "novelty_assets_bucket" {
  bucket = "${local.name}-assets"

  tags = merge(local.common_tags, {
    Name = "${local.name}-assets"
  })
}


# ------------------------------------------------------------------------------
# S3 Bucket Ownership
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "novelty_assets_ownership" {
  bucket = aws_s3_bucket.novelty_assets_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


# ------------------------------------------------------------------------------
# S3 Public Access Block
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "novelty_assets_public_access_block" {
  bucket = aws_s3_bucket.novelty_assets_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ------------------------------------------------------------------------------
# S3 Server-Side Encryption
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "novelty_assets_encryption" {
  bucket = aws_s3_bucket.novelty_assets_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# ------------------------------------------------------------------------------
# S3 Versioning
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "novelty_assets_versioning" {
  bucket = aws_s3_bucket.novelty_assets_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
