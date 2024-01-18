variable "image_tag_filters" {
  default     = ["*:*"]
  description = "List of SOCI repository image tag filters. Each filter is a repository name followed by a colon, \":\" and followed by a tag. Both repository names and tags may contain wildcards denoted by an asterisk, \"*\". For example, \"prod*:latest\" matches all images tagged with \"latest\" that are pushed to any repositories that start with \"prod\", while \"dev:*\" matches all images pushed to the \"dev\" repository. Use \"*:*\" to match all images pushed to all repositories in your private registry. This stack builds a SOCI index for any images that are pushed to your private registry after this stack is  created and match at least one filter. Empty values are NOT accepted."
  type        = list(string)
}

variable "s3_bucket_name" {
  default     = "aws-quickstart"
  description = "Name of the S3 bucket for your copy of the deployment assets. Keep the default name unless you are customizing the template. Changing the name updates code references to point to a new location."
  type        = string
}

variable "s3_key_prefix" {
  default     = "cfn-ecr-aws-soci-index-builder/"
  description = "S3 key prefix that is used to simulate a folder for your copy of the deployment assets. Keep the default prefix unless you are customizing the template. Changing the prefix updates code references to point to a new location."
  type        = string
}

variable "tags" {
  default     = {}
  description = "AWS tags to apply to resources."
  type        = map(string)
}
