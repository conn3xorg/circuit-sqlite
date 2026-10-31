# Facts give each host's distribution, which picks the package name.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }
}

circuit "sqlite" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "sqlite3" : "sqlite"
    }
  }

  # SQLite writes its journal beside the database, so the owner needs the
  # directory too. A directory that's already there is left as it is: it might
  # be /var/lib. A database that's already there keeps its contents.
  step "database" {
    for_each = var.databases
    command {
      command = "d=$(dirname '${item.key}'); [ -d \"$d\" ] || install -d -o '${item.value.owner}' -g '${coalesce(item.value.group, item.value.owner)}' -m 0750 \"$d\"; [ -s '${item.key}' ] || sqlite3 '${item.key}' 'VACUUM;'; chown '${item.value.owner}:${coalesce(item.value.group, item.value.owner)}' '${item.key}' && chmod '${item.value.mode}' '${item.key}'"
      unless  = "[ -s '${item.key}' ] && [ \"$(stat -c '%U:%G %a' '${item.key}')\" = '${item.value.owner}:${coalesce(item.value.group, item.value.owner)} ${trimprefix(item.value.mode, "0")}' ]"
    }
  }
}
