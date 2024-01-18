# Terraform SOCI Index Builder

This module implements the CloudFormation configuration from [aws-ia/cfn-ecr-aws-soci-index-builder](https://github.com/aws-ia/cfn-ecr-aws-soci-index-builder).  Specifically:

* Terraform resources implementing the CloudFormation template [`SociIndexBuilder.yml`](https://github.com/aws-ia/cfn-ecr-aws-soci-index-builder/blob/main/templates/SociIndexBuilder.yml)
* Lambda source code is sourced by default from the same bucket as upstream for the [`soci-index-generator-lambda`](https://github.com/aws-ia/cfn-ecr-aws-soci-index-builder/tree/main/functions/source/soci-index-generator-lambda) and [ecr-image-action-event-filtering](https://github.com/aws-ia/cfn-ecr-aws-soci-index-builder/tree/main/functions/source/ecr-image-action-event-filtering) functions (`s3://aws-quickstart/cfn-ecr-aws-soci-index-builder/`).  However, the repository name parsing lambda has been adapted to not require CloudFormation Python libraries, see the [`soci_repository_name_parsing` source](./soci_repository_name_parsing/index.py) for details.

Known limitations:

* Images approaching 10GB or more in size will not work as that's the maximum ephemeral space available to AWS Lambda functions.

## Example

In this example, all images in the `geonode` repository and only the `ubuntu-server:production` image will have SOCI indexes generated and pushed to their ECR:

```terraform
module "eks" {
  source = "github.com/radiant-maxar/terraform-eks"

  image_tag_filters = [
     "geonode:*",
     "ubuntu-server:production",
  ]

  tags = {
     Name = "SOCI"
  }
}
```
