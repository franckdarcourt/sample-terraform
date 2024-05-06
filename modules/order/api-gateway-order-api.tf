resource "aws_lambda_function" "order_api_lambda" {
  s3_bucket     = "${var.release_packages_bucket_name}"
  s3_key        = "order-api.zip"
  function_name = "${var.stage_name}-order-api"
  handler       = "bootstrap"
  runtime       = "provided.al2"
  architectures = ["arm64"]

  role          = aws_iam_role.order_api_lambda_role.arn

  environment {
    variables = {
      LIVENESS_ENDPOINT= var.liveness_endpoint
      READINESS_ENDPOINT= var.readiness_endpoint
      ORDERS_TABLE_NAME=aws_dynamodb_table.order_table.name
      ORDER_CREATED_SNS_ARN=var.order_created_sns_arn
      ORDER_DELETED_SNS_ARN=var.order_deleted_sns_arn
      PRODUCTS_TABLE_NAME=aws_dynamodb_table.product_table.name
    }
  }
}

resource "aws_lambda_permission" "order_api_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.order_api.execution_arn}/*/*/*"
}

data "aws_iam_policy_document" "order_api_lambda_role_iam_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "order_api_lambda_role" {
  name               = "${var.stage_name}-order-api-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.order_api_lambda_role_iam_policy.json
  inline_policy {
    name = "${var.stage_name}-order-api-lambda-role"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "dynamodb:*"
          ]
          Effect   = "Allow"
          Resource = [
            aws_dynamodb_table.order_table.arn,
          ]
        },
        {
          Action   = [
            "dynamodb:GetRecords"
          ]
          Effect   = "Allow"
          Resource = [
            "${aws_dynamodb_table.order_table.arn}/stream/*",
          ]
        },
        {
          Action   = [
            "dynamodb:Query"
          ]
          Effect   = "Allow"
          Resource = [
            "${aws_dynamodb_table.order_table.arn}/index/vaultIdIndex"
          ]
        },
        {
          Action   = "sns:Publish"
          Effect   = "Allow"
          Resource = [
            var.order_created_sns_arn,
            var.order_deleted_sns_arn,
          ]
        }
      ]
    })
  }
}

resource "aws_iam_role_policy_attachment" "order_api_lambda_role_policy_attachment" {
  role       = aws_iam_role.order_api_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_api_gateway_rest_api" "order_api" {
  name = "${var.stage_name}-order-api"
  description = "Order API"

  body = <<EOF
{
  "openapi" : "3.0.1",
  "info" : {
    "title" : "order-api",
    "description" : "Order API",
    "version" : "1.0"
  },
  "paths" : {
    "/api/orders/{orderId}" : {
      "get" : {
        "security" : [ {
          "CognitoUserPoolAuthorizer" : [ ]
        } ],
        "parameters" : [ {
          "name" : "orderId",
          "in" : "path",
          "required" : true,
          "schema" : {
            "type" : "string"
          }
        } ],
        "x-amazon-apigateway-integration" : {
          "httpMethod" : "POST",
          "uri" : "${aws_lambda_function.order_api_lambda.invoke_arn}",
          "passthroughBehavior" : "when_no_match",
          "type" : "aws_proxy"
        }
      },
      "delete" : {
        "security" : [ {
          "sigv4" : [ ]
        } ],
        "parameters" : [ {
          "name" : "orderId",
          "in" : "path",
          "required" : true,
          "schema" : {
            "type" : "string"
          }
        } ],
        "x-amazon-apigateway-integration" : {
          "httpMethod" : "POST",
          "uri" : "${aws_lambda_function.order_api_lambda.invoke_arn}",
          "passthroughBehavior" : "when_no_match",
          "type" : "aws_proxy"
        }
      }
    },
    "/api/orders" : {
      "get" : {
        "security" : [ {
          "sigv4" : [ ]
        } ],
        "x-amazon-apigateway-integration" : {
          "httpMethod" : "POST",
          "uri" : "${aws_lambda_function.order_api_lambda.invoke_arn}",
          "passthroughBehavior" : "when_no_match",
          "type" : "aws_proxy"
        }
      },
      "post" : {
        "security" : [ {
          "sigv4" : [ ]
        } ],
        "x-amazon-apigateway-integration" : {
          "httpMethod" : "POST",
          "uri" : "${aws_lambda_function.order_api_lambda.invoke_arn}",
          "passthroughBehavior" : "when_no_match",
          "type" : "aws_proxy"
        }
      }
    }
  },
  "components" : {
    "securitySchemes" : {
      "CognitoUserPoolAuthorizer" : {
        "type" : "apiKey",
        "name" : "Authorization",
        "in" : "header",
        "x-amazon-apigateway-authtype" : "cognito_user_pools",
        "x-amazon-apigateway-authorizer" : {
          "providerARNs" : [ "${var.cognito_user_pool_arn}" ],
          "type" : "cognito_user_pools"
        }
      },
      "sigv4": {
        "type": "apiKey",
        "name": "Authorization",
        "in": "header",
        "x-amazon-apigateway-authtype": "awsSigv4"
      }
    }
  }
}  
EOF
}

resource "aws_api_gateway_deployment" "order_api" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.order_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "order_api" {
  deployment_id = aws_api_gateway_deployment.order_api.id
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  stage_name    = var.stage_name
  depends_on    = [aws_cloudwatch_log_group.order_api]
}

resource "aws_api_gateway_method_settings" "order_api" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  stage_name  = aws_api_gateway_stage.order_api.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_cloudwatch_log_group" "order_api" {
  name              = "API-gateway/execution-logs/${aws_api_gateway_rest_api.order_api.name}"
  retention_in_days = 7
  # ... potentially other configuration ...
}
