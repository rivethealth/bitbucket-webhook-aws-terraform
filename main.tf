data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_api_gateway_deployment" "bitbucket" {
  depends_on        = ["aws_api_gateway_integration_response.event"]
  stage_description = "${var.deploy_version}"
  stage_name        = ""
  rest_api_id       = "${aws_api_gateway_rest_api.bitbucket.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_integration" "event" {
  count                   = "${length(var.endpoints)}"
  credentials             = "${aws_iam_role.api.arn}"
  http_method             = "${aws_api_gateway_method.event.*.http_method[count.index]}"
  integration_http_method = "POST"
  resource_id             = "${aws_api_gateway_method.event.*.resource_id[count.index]}"
  rest_api_id             = "${aws_api_gateway_rest_api.bitbucket.id}"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:path//"

  request_parameters {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates {
    "application/json" = <<EOF
Action=Publish##
&Message=$util.urlEncode($input.body)##
&MessageAttributes.entry.1.Name=event##
&MessageAttributes.entry.1.Value.DataType=String##
&MessageAttributes.entry.1.Value.StringValue=$util.urlEncode($input.params('X-Event-Key'))##
&MessageAttributes.entry.2.Name=signature##
&MessageAttributes.entry.2.Value.DataType=String##
&MessageAttributes.entry.2.Value.StringValue=$util.urlEncode($input.params('X-Hub-Signature'))##
&TopicArn=${urlencode(aws_sns_topic.event.*.arn[count.index])}##
EOF
  }
}

resource "aws_api_gateway_integration_response" "event" {
  count       = "${length(var.endpoints)}"
  rest_api_id = "${aws_api_gateway_rest_api.bitbucket.id}"
  resource_id = "${aws_api_gateway_method.event.*.resource_id[count.index]}"
  http_method = "POST"
  status_code = "${aws_api_gateway_method_response.event-200.*.status_code[count.index]}"
  depends_on  = ["aws_api_gateway_integration.event"]
}

resource "aws_api_gateway_method" "event" {
  authorization        = "NONE"                                                # authorizers do not have access to the body
  count                = "${length(var.endpoints)}"
  http_method          = "POST"
  request_validator_id = "${aws_api_gateway_request_validator.bitbucket.id}"
  resource_id          = "${aws_api_gateway_resource.event.*.id[count.index]}"
  rest_api_id          = "${aws_api_gateway_rest_api.bitbucket.id}"

  request_parameters {
    method.request.header.X-Event-Key = true
  }
}

resource "aws_api_gateway_method_response" "event-200" {
  count       = "${length(var.endpoints)}"
  http_method = "${aws_api_gateway_method.event.*.http_method[count.index]}"
  resource_id = "${aws_api_gateway_method.event.*.resource_id[count.index]}"
  rest_api_id = "${aws_api_gateway_rest_api.bitbucket.id}"
  status_code = 200
}

resource "aws_api_gateway_method_settings" "bitbucket" {
  method_path = "*/*"
  rest_api_id = "${aws_api_gateway_rest_api.bitbucket.id}"
  stage_name  = "${aws_api_gateway_stage.bitbucket.stage_name}"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_request_validator" "bitbucket" {
  name                        = "validate"
  rest_api_id                 = "${aws_api_gateway_rest_api.bitbucket.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_resource" "event" {
  count       = "${length(var.endpoints)}"
  parent_id   = "${aws_api_gateway_rest_api.bitbucket.root_resource_id}"
  path_part   = "${var.endpoints[count.index]}"
  rest_api_id = "${aws_api_gateway_rest_api.bitbucket.id}"
}

resource "aws_api_gateway_rest_api" "bitbucket" {
  description = "bitbucket webhook consumer"
  name        = "${var.name}"
}

resource "aws_api_gateway_stage" "bitbucket" {
  deployment_id = "${aws_api_gateway_deployment.bitbucket.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.bitbucket.id}"
  stage_name    = "latest"

  access_log_settings {
    destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/bitbucket/webhook/access"
    format          = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] $context.httpMethod $context.resourcePath $context.protocol $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_iam_role" "api" {
  name = "${var.name}-api"
  path = "/bitbucket/"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy" "api-sns" {
  name = "sns"
  role = "${aws_iam_role.api.id}"

  policy = <<EOF
{
  "Statement": [
    {
      "Action": "sns:Publish",
      "Effect": "Allow",
      "Resource": ${jsonencode(aws_sns_topic.event.*.arn)}
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_sns_topic" "event" {
  count = "${length(var.endpoints)}"
  name  = "${var.name}-${var.endpoints[count.index]}"
}
