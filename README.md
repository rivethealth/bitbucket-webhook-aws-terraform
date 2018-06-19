# Bitbucket webhook to AWS SNS

Publish Bitbucket webhook events to AWS SNS, enabling easy consumption by Lambda or other subscribers in the AWS ecosystem.

* [Inputs](#inputs)
* [Outputs](#outputs)
* [Setup](#setup)
* [Examples](#usage)
  * [Basic](#basic)
  * [Custom domain](#custom-domain)

## Usage

Multiple HTTP resources can be created. Each corresponds to a separate SNS topic.

SNS messages have an attribute "event" with the contents of X-Event-Key. You may use this for subscription [filter policies](https://docs.aws.amazon.com/sns/latest/dg/message-filtering.html).

The "signature" attribute is "sha256=&lt;hmac>". The message contents have not been validated with the signature; consumer must do that.

### Inputs

| Name | Type | Description | Default |
|------|:----:|-------------|:-------:|
| deploy_version | string | Arbitrary version to force deployment of API gateway | "1" |
| endpoints | list | Names of endpoints | ["all"] |
| name | string | Namespace for resources | "bitbucket-events" |

### Outputs

| Name | Type | Description |
|------|:----:|-------------|
| gateway_api_id | string | ID of API gateway |
| gateway_invoke_url | string | URL of deployed API |
| gateway_stage_name | string | Stage name of API gateway |
| sns_topic_arns | list | ARNs of SNS topics |

Requests can be made against "${gateway_invoke_url}/${endpoint}". (Or use a [custom domain](#custom-domain))

## Examples

### Basic

```hcl
module "bitbucket-events" {
  source         = "github.com/rivethealth/bitbucket-webhook-aws-terraform"
}
```

### Custom domain

```hcl
data "aws_acm_certificate" "bitbucket-events" {
  domain   = "bitbucket-events.example.com"
  statuses = ["ISSUED"]
}

module "bitbucket-events" {
  source         = "github.com/rivethealth/bitbucket-webhook-aws-terraform"
}

resource "aws_api_gateway_base_path_mapping" "bitbucket-events" {
  api_id      = "${module.bitbucket-events.gateway_api_id}"
  stage_name  = "${module.bitbucket-events.gateway_stage_name}"
  domain_name = "${aws_api_gateway_domain_name.bitbucket-events.domain_name}"
}

resource "aws_api_gateway_domain_name" "bitbucket-events" {
  certificate_arn = "${data.aws_acm_certificate.bitbucket-events.arn}"
  domain_name     = "bitbucket-events.example.com"
}
```

Note that a custom domain name will not be ready for several minutes.
