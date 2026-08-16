output "invoke_url" {
  description = "Public HTTPS URL of the order intake API endpoint"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/orders"
}
