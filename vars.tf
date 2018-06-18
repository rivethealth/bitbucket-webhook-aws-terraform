variable "deploy_version" {
  default = "1"
}

variable "endpoints" {
  default = ["all"]
  type    = "list"
}

variable "name" {
  default = "bitbucket-events"
}
