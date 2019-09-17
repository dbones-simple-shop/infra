provider "scaleway" {
  organization = "${var.organisation_id}"
  token        = "${var.token}"
  region       = "${var.region}"
}

variable "token" {
  type        = "string"
  description = "the account access token"
}

variable "organisation_id" {
  type        = "string"
  description = "your org id"
}

variable "region" {
  type        = "string"
  default     = "par1"
  description = "the region to setup"
}

variable "prefix" {
  default = "k8s"
}

variable "cluster_name" {
  default = "default"
}

variable "rancher_version" {
  default = "latest"
}

variable "docker_version_server" {
  default = "18.09"
}

variable "admin_password" {
  default = "epic-password&"
}

data "scaleway_image" "docker" {
  architecture = "x86_64"
  name         = "Ubuntu Bionic"
}

#################################
# Rancher SERVER
#################################
resource "scaleway_ip" "rancher_ip" {
  server = "${scaleway_server.rancher.id}"
}


resource "scaleway_server" "rancher" {
  image          = "${data.scaleway_image.docker.id}"
  type           = "DEV1-S"
  name           = "${var.prefix}-rancher"
  security_group = "${scaleway_security_group.http.id}"
}

resource "scaleway_user_data" "rancher_data" {
  server = "${scaleway_server.rancher.id}"
  key    = "cloud-init"
  value  = "${data.template_file.rancher_template.rendered}"
}

data "template_file" "rancher_template" {
  template = "${file("files/userdata_rancher")}"

  vars = {
    admin_password        = "${var.admin_password}"
    rancher_version       = "${var.rancher_version}"
    rancher_server_url    = "https://${scaleway_ip.rancher_ip.ip}"
    docker_version_server = "${var.docker_version_server}"
  }
}

#################################
# Control Panel
#################################
resource "scaleway_server" "ctl_pnl" {
  image               = "${data.scaleway_image.docker.id}"
  type                = "DEV1-M"
  name                = "${var.prefix}-ctl-pnl"
  security_group      = "${scaleway_security_group.nothing_allowed.id}"
  dynamic_ip_required = true
}

resource "scaleway_user_data" "ctl_pnl_data" {
  server = "${scaleway_server.ctl_pnl.id}"
  key    = "cloud-init"
  value  = "${data.template_file.ctl_pnl_template.rendered}"
}

data "template_file" "ctl_pnl_template" {
  template = "${file("files/userdata_ctl_pnl")}"

  vars = {
    server_address        = "${scaleway_ip.rancher_ip.ip}"
    #server_address        = "${scaleway_server.rancher.public_ip}"
    docker_version_server = "${var.docker_version_server}"
    admin_password        = "${var.admin_password}"
    cluster_name          = "${var.cluster_name}"
  }
}

#################################
# Nodes
#################################
resource "scaleway_server" "node" {
  count               = "2"
  image               = "${data.scaleway_image.docker.id}"
  type                = "DEV1-M"
  name                = "${var.prefix}-node-${count.index}"
  security_group      = "${scaleway_security_group.nothing_allowed.id}"
  dynamic_ip_required = true
}

resource "scaleway_user_data" "note_data" {
  count  = 2
  server = "${scaleway_server.node.*.id[count.index]}"
  key    = "cloud-init"
  value  = "${data.template_file.node_template.rendered}"
}

data "template_file" "node_template" {
  template = "${file("files/userdata_node")}"

  vars = {
    server_address        = "${scaleway_ip.rancher_ip.ip}"
    admin_password        = "${var.admin_password}"
    cluster_name          = "${var.cluster_name}"
    docker_version_server = "${var.docker_version_server}"
  }
}

#################################
# proxy instance
#################################
resource "scaleway_ip" "public_ip" {
  server = "${scaleway_server.proxy.id}"
}

resource "scaleway_server" "proxy" {
  image               = "${data.scaleway_image.docker.id}"
  type                = "DEV1-S"
  name                = "${var.prefix}-proxy"
  security_group      = "${scaleway_security_group.nothing_allowed.id}"
}

resource "scaleway_user_data" "proxy_data" {
  server = "${scaleway_server.proxy.id}"
  key    = "cloud-init"
  value  = "${data.template_file.node_template.rendered}"
}

#################################
# security groups
#################################
resource "scaleway_security_group" "http" {
  name        = "http"
  description = "allow HTTP and HTTPS traffic"
}

resource "scaleway_security_group" "nothing_allowed" {
  name        = "nothing_allowed"
  description = "not traffic allowed"
}

resource "scaleway_security_group_rule" "http_accept" {
  security_group = "${scaleway_security_group.http.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 80
}

resource "scaleway_security_group_rule" "https_accept" {
  security_group = "${scaleway_security_group.http.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 443
}
