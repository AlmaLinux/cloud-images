resource "opennebula_virtual_machine" "opennebula-test-1" {
  name        = "ALCIB aarch64 Test 1"
  description = "Testing OpemNebula Images on aarch64"
  template_id = opennebula_template.opennebula-aarch64.id
  group       = var.group

  context = {
    NETWORK      = "YES"
    SET_HOSTNAME = "almalinux-test-1"
  }
}

resource "opennebula_virtual_machine" "opennebula-test-2" {
  name        = "ALCIB aarch64 Test 2"
  description = "Testing OpemNebula Images on aarch64"
  template_id = opennebula_template.opennebula-aarch64.id
  group       = var.group

  context = {
    NETWORK      = "YES"
    SET_HOSTNAME = "almalinux-test-1"
  }
}

resource "local_file" "ssh_client_config" {
  content = templatefile("ssh-config.tftpl", {
    "Host1" = opennebula_virtual_machine.opennebula-test-1.ip
    "Host2" = opennebula_virtual_machine.opennebula-test-2.ip
    }
  )
  filename = "${path.module}/ssh-config"
}
