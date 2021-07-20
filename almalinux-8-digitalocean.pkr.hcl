/*
 * AlmaLinux OS 8 Packer template for building DigitalOcean images.
 */

packer {
  required_plugins {
    do = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/digitalocean"
    }
  }
}


source "digitalocean" "almalinux-8-digitalocean-x86_64" {
  api_token        = var.do_api_token
  image            = var.do_image
  ipv6             = false
  region           = var.do_region
  size             = var.do_size
  snapshot_name    = var.do_snapshot_name
  ssh_username     = "root"
  tags             = var.do_tags
}


build {
  sources = ["digitalocean.almalinux-8-digitalocean-x86_64"]

  provisioner "shell" {
    scripts = [
      "vm-scripts-digitalocean/00-wait_for_cloud-init.bash",
      "vm-scripts-digitalocean/10-dnf_upgrade.bash",
      "vm-scripts-digitalocean/50-mangle_os-release.bash",
      "vm-scripts-digitalocean/80-root_lock-up.bash",
      "vm-scripts-digitalocean/89-root_clean-up.bash",
      "vm-scripts-digitalocean/90-cleanup.bash",
      "vm-scripts-digitalocean/99-img-check.bash"
    ]
  }
}

