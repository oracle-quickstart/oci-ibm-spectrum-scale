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
  ingress_security_rules {
    tcp_options  {
      max = 22
      min = 22
    }
    protocol = "6"
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




