variable "pub_ssh_key" {
    description = "Public SSH key to be used for the server"
    type        = string
    default     = null
}

variable "ssh_key_name" {
    description = "Name of the SSH key to be used for the server"
    type        = string
    default     = "nixos-anywhere-ssh-key"
}

variable "priv_ssh_key" {
    description = "Private SSH key to be used for the server (is used to connect to the server)"
    type        = string
    default     = null
}

variable "server_name" {
    description = "Name of the server to be created"
    type        = string
    default     = "nixos-anywhere-server"
}

variable "server_type" {
    description = "Type of the server to be created"
    type        = string
    default     = "cpx11"
}

variable "location" {
    description = "Location of the server to be created"
    type        = string
    default     = "fsn1"
}

variable "hcloud_token" {
    description = "Hetzner Cloud API token"
    type        = string
    default     = null
}

