# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

variable "k8s_host" {
  default = "https://kubernetes.default.svc"
}

variable "k8s_config_context" {
  default = "docker-desktop"
}

variable "k8s_config_path" {
  default = "~/.kube/config"
}