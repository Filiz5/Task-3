output "public_ip" {
    value = aws_instance.devops_project_instance[0].public_ip
}