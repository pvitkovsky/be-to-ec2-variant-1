# required for AWS
variable "access_key" {
    description = "Access key to AWS console"
}
variable "secret_key" {
    description = "Secret key to AWS console"
}
variable "region" {
    description = "Region of AWS VPC"
}
variable "s3_bucket_name" {
    description = "S3 with static jar for testing"
}
variable "jar_file_name" {
    description = "Static jar name"
}
