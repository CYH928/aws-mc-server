# ── Watcher IAM: can start MC instance ───────────────────────────────────

resource "aws_iam_role" "watcher" {
  name = "mc-watcher-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "watcher_policy" {
  name = "mc-watcher-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:StartInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "watcher" {
  role       = aws_iam_role.watcher.name
  policy_arn = aws_iam_policy.watcher_policy.arn
}

resource "aws_iam_instance_profile" "watcher" {
  name = "mc-watcher-profile"
  role = aws_iam_role.watcher.name
}

# ── MC Server IAM: can stop itself + write S3 backups ────────────────────

resource "aws_iam_role" "minecraft" {
  name = "mc-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "minecraft_policy" {
  name = "mc-server-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ec2:StopInstances"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Name" = "minecraft-server"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          aws_s3_bucket.backup.arn,
          "${aws_s3_bucket.backup.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "minecraft" {
  role       = aws_iam_role.minecraft.name
  policy_arn = aws_iam_policy.minecraft_policy.arn
}

resource "aws_iam_instance_profile" "minecraft" {
  name = "mc-server-profile"
  role = aws_iam_role.minecraft.name
}
