output "instance1_public_ip" {
  value = aws_instance.ami_test-1.public_ip
}

output "instance2_public_ip" {
  value = aws_instance.ami_test-2.public_ip
}

output "instance_id1" {
  value = aws_instance.ami_test-1.id
}

output "instance_id2" {
  value = aws_instance.ami_test-2.id
}
