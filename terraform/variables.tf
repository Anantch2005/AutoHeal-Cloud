variable "region_primary" {
  default = "ap-south-1"
}

variable "region_secondary" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id_primary" {
  default = "ami-0dee22c13ea7a9a67" 
}

variable "ami_id_secondary" {
  default = "ami-0fc5d935ebf8bc3bc"
}
