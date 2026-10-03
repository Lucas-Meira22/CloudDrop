# Lets AWS trust tokens signed by GitHub Actions (one per account per URL)
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Token must be meant for AWS STS
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only pushes to main in this repo, not forks, PRs or other branches.
    # GitHub's immutable subject adds the owner and repo IDs, so a new repo reusing the name can't match
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Lucas-Meira22@82990073/CloudDrop@1387493323:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name                 = "${var.project_name}-github-ci"
  assume_role_policy   = data.aws_iam_policy_document.github_assume.json
  max_session_duration = 3600
}


data "aws_iam_policy_document" "github_ci" {
  # Docker login to ECR. This API has no resource-level permissions, so "*" is required
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push image layers and the manifest, to this repository only
  statement {
    sid = "PushToClouddropRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "github_ci" {
  name   = "${var.project_name}-github-ci-ecr-push"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.github_ci.json
}
