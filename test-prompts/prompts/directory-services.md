# Domain: Active Directory, LDAP, LDAP Partitioning & Group Policy

Design and implement a complete enterprise directory services architecture for a company with 3 divisions across 2 continents. Requirements:

**Active Directory (Windows):**
1. Forest/Division design: parent corp.local with child domains for each division
2. OU structure: by function (Users, Computers, Servers, ServiceAccounts, Groups) then by location
3. Group Policy Objects: 5 GPOs covering password policy, BitLocker enforcement, Windows Update rings, security baseline (CIS Level 2), and application allowlisting
4. Delegation model: helpdesk can reset passwords in their division only

**LDAP (OpenLDAP):**
1. Directory Information Tree design with backends for: people, groups, services, devices, policies
2. Partition strategy: people by division (3 partitions), groups by function (2 partitions)
3. Replication: multi-master across 2 sites with syncrepl
4. ACLs: self-write for phone number, group-admin for membership, service accounts read-only for apps

**Linux Integration:**
1. SSSD configuration for AD auth with failover to local
2. Samba 4 as AD DC alternative: provision command + smb.conf
3. PAM/NSS configuration for LDAP-backed users
4. Automount via autofs for NFS home directories

**Group Policy for Linux:**
1. Ansible playbook enforcing: password aging, sudoers, file permissions, auditd rules, kernel parameters
2. Puppet manifest for GNOME lockdown (org.gnome.desktop.lockdown, screensaver, media handling)

Deliver: ad-architecture.ldif, gpo-export/, sssd.conf, smb.conf, ansible-playbook.yml, puppet-module/, network-diagram.md
