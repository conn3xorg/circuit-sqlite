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
  # be /var/lib. A database that's already there keeps its contents. Root only
  # does this work where nobody else can change the path; anywhere else it's
  # done as the owner, so it can't reach what the owner couldn't.
  step "database" {
    for_each = var.databases
    command {
      command = <<-EOT
        set -e
        db='${item.key}' o='${item.value.owner}' g='${coalesce(item.value.group, item.value.owner)}' m='${item.value.mode}'
        # True when no account but root can change any part of the path, walked as
        # written, or of where any link on the way points, one link at a time.
        only_root_changes() {
          case $1 in /*) ;; *) return 1 ;; esac
          [ "$${2:-0}" -lt 40 ] || return 1
          # The /. keeps a trailing slash from hiding a link from -L.
          p=$1/.
          while :; do
            if [ -L "$p" ]; then
              [ "$(stat -c %u -- "$p")" = 0 ] || return 1
              t=$(readlink -- "$p")
              case $t in /*) ;; *) t=$(dirname -- "$p")/$t ;; esac
              (only_root_changes "$t" $(($${2:-0} + 1))) || return 1
            elif [ -e "$p" ]; then
              [ "$(stat -c %u -- "$p")" = 0 ] && [ $((0$(stat -c %a -- "$p") & 022)) = 0 ] || return 1
            fi
            [ "$p" != / ] || return 0
            p=$(dirname -- "$p")
          done
        }
        d=$(dirname -- "$db")
        if ! [ -d "$d" ] && only_root_changes "$d"; then install -d -o "$o" -g "$g" -m 0750 "$d"; fi
        if only_root_changes "$d"; then
          [ -s "$db" ] || sqlite3 "$db" 'VACUUM;'
          chown "$o:$g" "$db"
          chmod "$m" "$db"
        elif [ "$o" = root ]; then
          echo "$d can be changed by an account other than root, so root won't own a database there" >&2
          exit 1
        else
          # Someone else can change the path, so this runs with only the owner's rights.
          cd /
          runuser -u "$o" -g "$g" -- sh -ec '
            mkdir -p -m 0750 "$(dirname -- "$1")"
            [ -s "$1" ] || sqlite3 "$1" "VACUUM;"
            chgrp "$2" "$1"
            chmod "$3" "$1"
          ' sh "$db" "$g" "$m" || {
            echo "$o couldn't set up $db. If another user owns it, change its owner once by hand" >&2
            exit 1
          }
        fi
      EOT
      unless  = "[ -s '${item.key}' ] && [ \"$(stat -c '%U:%G %a' '${item.key}')\" = '${item.value.owner}:${coalesce(item.value.group, item.value.owner)} ${trimprefix(item.value.mode, "0")}' ]"
    }
  }
}
