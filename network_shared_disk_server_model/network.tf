/*
All network resources for this template
*/

resource "oci_core_vcn" "vcn" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block = var.vpc_cidr
  compartment_id = var.compartment_ocid
  display_name = "gpfs"
  dns_label = "gpfs"
}

resource "oci_core_internet_gateway" "internet_gateway" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name = "internet_gateway"
  vcn_id = oci_core_vcn.vcn[0].id
}

resource "oci_core_route_table" "pubic_route_table" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.vcn[0].id
  display_name = "RouteTableForComplete"
  route_rules {
    cidr_block = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.internet_gateway[0].id
  }
}


resource "oci_core_nat_gateway" "nat_gateway" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn[0].id
  display_name   = "nat_gateway"
}


resource "oci_core_route_table" "private_route_table" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn[0].id
  display_name   = "private_route_tableForComplete"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.nat_gateway[0].id
  }
}

resource "oci_core_security_list" "public_security_list" {
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name = "Public Subnet"
  vcn_id = oci_core_vcn.vcn[0].id
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
  count          = var.use_existing_vcn ? 0 : 1
  compartment_id = var.compartment_ocid
  display_name   = "Private"
  vcn_id         = oci_core_vcn.vcn[0].id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  egress_security_rules {
    protocol    = "all"
    destination = var.vpc_cidr
  }
# for Mgmt GUI:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforgui.htm
  ingress_security_rules  {
    tcp_options  {
      max = 443
      min = 443
    }
    protocol = "6"
    source   = var.vpc_cidr
  }
  ingress_security_rules {
    tcp_options  {
      max = 22
      min = 22
    }
    protocol = "6"
    source   = var.vpc_cidr
  }
  ingress_security_rules  {
    tcp_options {
      max = 80
      min = 80
    }
    protocol = "6"
    source   = var.vpc_cidr
  }
  ingress_security_rules  {
    tcp_options  {
      max = 443
      min = 443
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
   # for Object Storage on CES node:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforprotaccess.htm
  ingress_security_rules  {
    tcp_options  {
      max = 8080
      min = 8080
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
# for SMB on CES node:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforprotaccess.htm
  ingress_security_rules  {
    tcp_options  {
      max = 445
      min = 445
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    tcp_options  {
      max = 4379
      min = 4379
    }
    protocol = "6"
    source   = var.vpc_cidr
  }

# for NFSV4&NFSV3 on CES node:  https://www.ibm.com/support/knowledgecenter/en/STXKQY_5.0.3/com.ibm.spectrum.scale.v5r03.doc/bl1adv_firewallforprotaccess.htm
  ingress_security_rules  {
    tcp_options  {
      max = 2049
      min = 2049
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    tcp_options  {
      max = 111
      min = 111
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    tcp_options  {
      max = 32765
      min = 32765
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    tcp_options  {
      max = 32767
      min = 32767
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
   ingress_security_rules  {
    tcp_options  {
      max = 32768
      min = 32768
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
   ingress_security_rules  {
    tcp_options  {
      max = 32769
      min = 32769
    }
    protocol = "6"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    udp_options  {
      max = 2049
      min = 2049
    }
    protocol = "17"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    udp_options  {
      max = 111
      min = 111
    }
    protocol = "17"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    udp_options  {
      max = 32765
      min = 32765
    }
    protocol = "17"
    source   = var.vpc_cidr
   }
  ingress_security_rules  {
    udp_options  {
      max = 32767
      min = 32767
    }
    protocol = "17"
    source   = var.vpc_cidr
   }
   ingress_security_rules  {
    udp_options  {
      max = 32768
      min = 32768
    }
    protocol = "17"
    source   = var.vpc_cidr
   }
   ingress_security_rules  {
    udp_options  {
      max = 32769
      min = 32769
    }
    protocol = "17"
    source   = var.vpc_cidr
   }

   ingress_security_rules  {
     protocol = "All"
     source = var.vpc_cidr
   }
}


# Regional subnet - public
resource "oci_core_subnet" "public" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  #display_name      = "${local.cluster_name}_public"
  display_name      = "Public-Subnet"
  compartment_id = var.compartment_ocid
  vcn_id = oci_core_vcn.vcn[0].id
  route_table_id    = oci_core_route_table.pubic_route_table[0].id
  security_list_ids = [oci_core_security_list.public_security_list[0].id]
  dhcp_options_id   = oci_core_vcn.vcn[0].default_dhcp_options_id
  dns_label         = "public"
}


# Regional subnet - private
resource "oci_core_subnet" "storage" {
  count          = var.use_existing_vcn ? 0 : 1
  cidr_block                 = cidrsubnet(var.vpc_cidr, 8, count.index+3)
  display_name               = "Private-SpectrumScale"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_vcn.vcn[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "storage"
}

# Regional subnet - private B
resource "oci_core_subnet" "fs" {
  count          = var.use_existing_vcn ? 0 : 1
  #(local.dual_nics ? 1 : 0)
  cidr_block                 = cidrsubnet(var.vpc_cidr, 8, count.index+6)
  display_name               = "Private-FS-Subnet"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_vcn.vcn[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "fs"
}

# Regional subnet - private for CES/TCT/Protocol nodes.
resource "oci_core_subnet" "protocol_subnet" {
  count          = var.use_existing_vcn ? 0 : 1
  #(local.dual_nics ? 1 : 0)
  cidr_block                 = cidrsubnet(var.vpc_cidr, 8, count.index+9)
  display_name               = "privateprotocol_${count.index}"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.vcn[0].id
  route_table_id             = oci_core_route_table.private_route_table[0].id
  security_list_ids          = [oci_core_security_list.private_security_list[0].id]
  dhcp_options_id            = oci_core_vcn.vcn[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "privprotocol${count.index}"
}
