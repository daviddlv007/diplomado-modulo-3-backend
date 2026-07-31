variable "project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "aws_region" {
  type        = string
  description = "Región AWS"
}

variable "ami" {
  type        = string
  description = "AMI de la instancia"
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia"
}

variable "key_name" {
  type        = string
  description = "Key pair para EC2"
}

variable "volume_size" {
  type        = number
  description = "Tamaño del volumen"
}

variable "volume_type" {
  type        = string
  description = "Tipo de volumen"
}
