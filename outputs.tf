output "sqlite3" {
  description = "Path of the sqlite3 command on each host, by host name. It's the same on every supported distribution; the version isn't."
  value       = { for name in keys(var.hosts) : name => "/usr/bin/sqlite3" }
}
