terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.0"
    }
    template = {
      source  = "cloudposse/template"
      version = ">= 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 1.3"
    }
    opsgenie = {
      source  = "opsgenie/opsgenie"
      version = ">= 0.5.0"
    }
  }
}
