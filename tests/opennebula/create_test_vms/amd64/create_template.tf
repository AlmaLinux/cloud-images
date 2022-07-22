resource "opennebula_template" "opennebula-amd64" {
  name        = "OpenNebula x86_64 ALCIB Template"
  description = "This template will be tested as a part of AlmalInux Cloud Image Builder"
  cpu         = 1
  vcpu        = 1
  memory      = 2048
  group       = var.group

  context = {
    NETWORK        = "YES"
    USERNAME       = "almalinux"
    SSH_PUBLIC_KEY = "${var.ssh_pub_key}"
  }

  os {
    arch = "x86_64"
    boot = ""
  }

  disk {
    image_id = opennebula_image.opennebula-amd64.id
    size     = "10240"
  }

  nic {
    network_id = var.network_id
  }
}
