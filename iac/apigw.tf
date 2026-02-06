resource "aws_apigatewayv2_api" "api_gw" {
  name          = "claim-app-api-gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "eks-vpc-link"
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = []
}

resource "aws_apigatewayv2_integration" "eks" {
  api_id           = aws_apigatewayv2_api.api_gw.id
  integration_type = "HTTP_PROXY"

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.eks.id

  integration_method = "ANY"
  integration_uri    = data.aws_lb_listener.eks.arn
}

resource "aws_apigatewayv2_route" "api" {
  api_id    = aws_apigatewayv2_api.api_gw.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api_gw.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    logging_level           = "INFO"
    throttling_burst_limit  = 5000
    throttling_rate_limit   = 10000
  }
}