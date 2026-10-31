variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "databases" {
  type = map(object({
    owner = optional(string, "root")
    group = optional(string)
    mode  = optional(string, "0640")
  }))
  default     = {}
  description = "Empty databases to create, by absolute path, with their owner, group (the owner's name when null) and mode. A database that exists keeps its contents."

  validation {
    condition     = alltrue([for path in keys(var.databases) : can(regex("^/[A-Za-z0-9._/-]*[A-Za-z0-9._-]$", path))])
    error_message = "Each key of databases must be an absolute path, such as \"/var/lib/app/app.db\"."
  }

  validation {
    condition     = alltrue([for d in values(var.databases) : can(regex("^[a-z_][a-z0-9_-]*$", d.owner)) && can(regex("^[a-z_][a-z0-9_-]*$", coalesce(d.group, d.owner)))])
    error_message = "Each owner and group in databases must be a plain user or group name."
  }

  validation {
    condition     = alltrue([for d in values(var.databases) : can(regex("^0[0-7]{3}$", d.mode))])
    error_message = "Each mode in databases must be four octal digits, such as \"0640\"."
  }
}
