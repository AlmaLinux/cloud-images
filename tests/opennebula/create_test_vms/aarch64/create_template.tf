resource "opennebula_template" "opennebula-aarch64" {
  name        = "OpenNebula aarch64 ALCIB Template"
  description = "This template will be tested as a part of AlmalInux Cloud Image Builder"
  cpu         = 1
  vcpu        = 1
  memory      = 2048
  group       = var.group

  context = {
    DEV_PREFIX     = "vd"
    NETWORK        = "YES"
    USERNAME       = "almalinux"
    SSH_PUBLIC_KEY = "${var.ssh_pub_key}"
  }

  os {
    arch = "aarch64"
    boot = ""
  }

  disk {
    image_id = opennebula_image.opennebula-aarch64.id
  }

  nic {
    network_id = var.network_id
  }

  raw {
    type = "kvm"
    data = "<os firmware='efi'><loader readonly='yes' type='pflash'>/usr/share/AAVMF/AAVMF_CODE.fd</loader></os><cpu mode='host-passthrough'/><devices><input type='keyboard' bus='virtio'/><input type='mouse' bus='virtio'/></devices>"
  }
}
