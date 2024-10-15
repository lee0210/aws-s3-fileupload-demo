variable "region" {
  default = "ap-southeast-2"
}

variable "tags" {
    type = map(string)
    default = {
        "Terraform" = "True"
        "Environment" = "Dev"
    }
}

variable "resource_prefix" {
    type = string
    default = "aws-s3-demo"
}

variable "image_name" {
    type = string
    default = "express-app"
}

variable "image_tag" {
    type = string
    default = "latest"
}

variable "api_stage_name" {
    type = string
    default = "v1"
}