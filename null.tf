resource "null_resource" "cluster" {
  count = var.environment == "prod" ? 3 : 1
  provisioner "file" {
    source      = "uder-data.sh"
    destination = "/tmp/uder-data.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("amma.pem")
      host        = element(aws_instance.public_instance_1.*.public_ip, count.index)
    }
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 777 /tmp/uder-data.sh",
      "sudo /tmp/uder-data.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("amma.pem")
      host        = element(aws_instance.public_instance_1.*.public_ip, count.index)
    }
  }
}
