resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.api_gw.name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_dashboard" "claims_app" {
  dashboard_name = "claims-app-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["ClaimsApp", "RequestDuration", { stat = "Average" }],
            ["...", { stat = "p99" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "API Response Times"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum" }],
            [".", "4XXError", { stat = "Sum" }],
            [".", "5XXError", { stat = "Sum" }]
          ]
          period = 300
          region = var.region
          title  = "API Gateway Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.api_gw.name}' | fields @timestamp, requestId, httpMethod, routeKey, status, errorMessage | filter status >= 400 | sort @timestamp desc | limit 20"
          region  = var.region
          title   = "API Gateway Errors"
          stacked = false
        }
      },
      {
        type = "log"
        properties = {
          query   = "SOURCE '/aws/containerinsights/${var.cluster_name}/application' | fields @timestamp, kubernetes.namespace_name, kubernetes.pod_name, log | filter kubernetes.namespace_name = 'default' | sort @timestamp desc | limit 50"
          region  = var.region
          title   = "EKS Application Logs"
          stacked = false
        }
      }
    ]
  })
}