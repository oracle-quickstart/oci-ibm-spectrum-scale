/*
All network resources for this template
*/

resource "oci_core_virtual_network" "gpfs" {
  cidr_block = "${var.vpc_cidr}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "gpfs"
  dns_label = "gpfs"
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "internet_gateway"
  vcn_id = "${oci_core_virtual_network.gpfs.id}"
}

resource "oci_core_route_table" "pubic_route_table" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.gpfs.id}"
  display_name = "RouteTableForComplete"
  route_rules {
    cidr_block = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.internet_gateway.id}"
  }
}


resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.gpfs.id}"
  display_name   = "nat_gateway"
}


resource "oci_core_route_table" "private_route_table" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.gpfs.id}"
  display_name   = "private_route_tableForComplete"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_nat_gateway.nat_gateway.id}"
  }
}

resource "oci_core_security_list" "public_security_list" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "Public Subnet"
  vcn_id = "${oci_core_virtual_network.gpfs.id}"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol = "6"
  }
  ingress_security_rules {
    tcp_options {
      max = 22
      min = 22
    }
    protocol = "6"
    source = "0.0.0.0/0"
  }
  ingress_security_rules {
    tcp_options {
      max = 3389
      min = 3389
    }
    protocol = "6"
    source   = "0.0.0.0/0"
  }
}

# https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewall.htm
resource "oci_core_security_list" "private_security_list" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Private"
  vcn_id         = "${oci_core_virtual_network.gpfs.id}"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  egress_security_rules {
    protocol    = "all"
    destination = "${var.vpc_cidr}"
  }
# for Mgmt GUI:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforgui.htm
  ingress_security_rules  {
    tcp_options  {
      max = 443
      min = 443
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
  }
  ingress_security_rules {
    tcp_options  {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
  }
  ingress_security_rules  {
    tcp_options {
      max = 80
      min = 80
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
  }
  ingress_security_rules  {
    tcp_options  {
      max = 443
      min = 443
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
   # for Object Storage on CES node:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforprotaccess.htm
  ingress_security_rules  {
    tcp_options  {
      max = 8080
      min = 8080
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
# for SMB on CES node:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforprotaccess.htm
  ingress_security_rules  {
    tcp_options  {
      max = 445
      min = 445
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    tcp_options  {
      max = 4379
      min = 4379
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
  }

# for NFSV4&NFSV3 on CES node:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforprotaccess.htm
  ingress_security_rules  {
    tcp_options  {
      max = 2049
      min = 2049
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    tcp_options  {
      max = 111
      min = 111
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    tcp_options  {
      max = 32765
      min = 32765
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    tcp_options  {
      max = 32767
      min = 32767
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
   ingress_security_rules  {
    tcp_options  {
      max = 32768
      min = 32768
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
   ingress_security_rules  {
    tcp_options  {
      max = 32769
      min = 32769
    }
    protocol = "6"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    udp_options  {
      max = 2049
      min = 2049
    }
    protocol = "17"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    udp_options  {
      max = 111
      min = 111
    }
    protocol = "17"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    udp_options  {
      max = 32765
      min = 32765
    }
    protocol = "17"
    source   = "${var.vpc_cidr}"
   }
  ingress_security_rules  {
    udp_options  {
      max = 32767
      min = 32767
    }
    protocol = "17"
    source   = "${var.vpc_cidr}"
   }
   ingress_security_rules  {
    udp_options  {
      max = 32768
      min = 32768
    }
    protocol = "17"
    source   = "${var.vpc_cidr}"
   }
   ingress_security_rules  {
    udp_options  {
      max = 32769
      min = 32769
    }
    protocol = "17"
    source   = "${var.vpc_cidr}"
   }

   ingress_security_rules  {
     protocol = "All"
     source = "${var.vpc_cidr}"
   }
}


# Regional subnet - public
resource "oci_core_subnet" "public" {
  count = "1"
  cidr_block = "${cidrsubnet(var.vpc_cidr, 8, count.index)}"
  display_name = "public_${count.index}"
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.gpfs.id}"
  route_table_id = "${oci_core_route_table.pubic_route_table.id}"
  security_list_ids = ["${oci_core_security_list.public_security_list.id}"]
  dhcp_options_id = "${oci_core_virtual_network.gpfs.default_dhcp_options_id}"
  dns_label = "public${count.index}"
}


# Regional subnet - private
resource "oci_core_subnet" "private" {
  count                      = "1"
  cidr_block                 = "${cidrsubnet(var.vpc_cidr, 8, count.index+3)}"
  display_name               = "private_${count.index}"
  compartment_id             = "${var.compartment_ocid}"
  vcn_id                     = "${oci_core_virtual_network.gpfs.id}"
  route_table_id             = "${oci_core_route_table.private_route_table.id}"
  security_list_ids          = ["${oci_core_security_list.private_security_list.id}"]
  dhcp_options_id            = "${oci_core_virtual_network.gpfs.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "private${count.index}"
}

# Regional subnet - private B
resource "oci_core_subnet" "privateb" {
  count                      = (local.dual_nics ? 1 : 0)
  cidr_block                 = "${cidrsubnet(var.vpc_cidr, 8, count.index+6)}"
  display_name               = "privateb_${count.index}"
  compartment_id             = "${var.compartment_ocid}"
  vcn_id                     = "${oci_core_virtual_network.gpfs.id}"
  route_table_id             = "${oci_core_route_table.private_route_table.id}"
  security_list_ids          = ["${oci_core_security_list.private_security_list.id}"]
  dhcp_options_id            = "${oci_core_virtual_network.gpfs.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "privateb${count.index}"
}

# Regional subnet - private for CES/TCT/Protocol nodes.
resource "oci_core_subnet" "privateprotocol" {
  count                      = (local.dual_nics ? 1 : 0)
  cidr_block                 = "${cidrsubnet(var.vpc_cidr, 8, count.index+9)}"
  display_name               = "privateprotocol_${count.index}"
  compartment_id             = "${var.compartment_ocid}"
  vcn_id                     = "${oci_core_virtual_network.gpfs.id}"
  route_table_id             = "${oci_core_route_table.private_route_table.id}"
  security_list_ids          = ["${oci_core_security_list.private_security_list.id}"]
  dhcp_options_id            = "${oci_core_virtual_network.gpfs.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "privprotocol${count.index}"
}
