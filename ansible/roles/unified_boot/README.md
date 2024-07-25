Unify Bootloader Configuration
=========

Unify bootloader configuration to support BIOS and UEFI boot at the same time.

Requirements
------------

None

Role Variables
--------------

None

Dependencies
------------

None

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - name: AlmaLinux Generic Cloud
      hosts: all
      become: true

      roles:
        - role: unified_boot
          when: is_unified_boot is defined
        - gencloud_guest
        - cleanup_vm

License
-------

GPL-3.0-only

Author Information
------------------

Cloud Special Interest Group (Cloud SIG) of AlmaLinux OS Foundation
