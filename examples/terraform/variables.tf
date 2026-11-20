variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "name" {
  description = "Prefix for resource names"
  type        = string
  default     = "lesson"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  description = "Who may reach port 80. Put your own IP (x.x.x.x/32) here for tighter security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
