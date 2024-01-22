variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string

}


variable "server_port" {
  description = "sever port for web service"
  type        = number
}

variable "min_size" {
  description = "min size of the web cluster"
  type        = number
}

variable "max_size" {
  description = "max size of the web cluster"
  type        = number
}


variable "cluster_name" {
  description = "prefix name of cluster"
  type        = string
}




