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

variable "server_type" {
    description = "Type of the server to be created"
    type        = string
    default     = "cpx11"
}

variable "agent_type" {
    description = "Type of the agent server to be created"
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

variable "extra_server_count" {
    description = "Number of server nodes to create op top of the main server node (this must be an even number because the server nodes are used for high availability)"
    type        = number
    default     = 2
    validation {
        condition     = var.extra_server_count == 0 || var.extra_server_count % 2 == 0
        error_message = "The number of extra server nodes must be an even number."
    }
}

variable "agent_count" {
    description = "Number of agent nodes to create"
    type        = number
    default     = 1
}

variable "cluster_name" {
    description = "Name prefix for the cluster resources"
    type        = string
    default     = "rke2-cluster"
}

variable "lb_type" {
    description = "Type of Hetzner load balancer to create (lb11, lb21, lb31)"
    type        = string
    default     = "lb11"
}
