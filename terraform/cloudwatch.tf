# CloudWatch billing metrics are ONLY available in us-east-1
# That's why we use the us_east_1 provider alias here

resource "aws_sns_topic" "billing_alert" {
  provider = aws.us_east_1
  name     = "minecraft-billing-alert"
}

resource "aws_sns_topic_subscription" "billing_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.billing_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  provider            = aws.us_east_1
  alarm_name          = "minecraft-monthly-billing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400 # check once per day
  statistic           = "Maximum"
  threshold           = var.billing_threshold_usd
  alarm_description   = "Alert when monthly AWS bill exceeds $${var.billing_threshold_usd} USD"
  treat_missing_data  = "notBreaching"
  dimensions          = { Currency = "USD" }
  alarm_actions       = [aws_sns_topic.billing_alert.arn]
}
