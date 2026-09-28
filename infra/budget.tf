# Adopts the budget created by hand during setup, instead of creating a duplicate.
# After the first apply, this block can be deleted: the budget is then in the state.
import {
  to = aws_budgets_budget.monthly
  id = "137286422208:clouddrop-monthly"
}

# Emails when the month's spend passes 85% and 100% of US$10,
# and early if AWS forecasts the month will end above US$10
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = "10.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Matches what the console set when the budget was created by hand
  billing_view_arn = "arn:aws:billing::137286422208:billingview/primary"
  metrics          = ["UnblendedCost"]

  # Counts real usage: Free Tier credits and refunds don't hide spend
  filter_expression {
    not {
      dimensions {
        key    = "RECORD_TYPE"
        values = ["Credit", "Refund"]
      }
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
