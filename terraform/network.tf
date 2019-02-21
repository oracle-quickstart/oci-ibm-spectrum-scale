/*
All network resources for this template
*/

resource "oci_core_virtual_network" "ibmss_vcn" {
  cidr_block = "${var.VPC-CIDR}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "ibmssvcn"
  dns_label = "ibmssvcn"
}

resource "oci_core_internet_gateway" "ibmss_internet_gateway" {
    compartment_id = "${var.compartment_ocid}"
    display_name = "ibmss_internet_gateway"
    vcn_id = "${oci_core_virtual_network.ibmss_vcn.id}"
}

resource "oci_core_route_table" "RouteForComplete" {
    compartment_id = "${var.compartment_ocid}"
    vcn_id = "${oci_core_virtual_network.ibmss_vcn.id}"
    display_name = "RouteTableForComplete"
    route_rules {
        cidr_block = "0.0.0.0/0"
        network_entity_id = "${oci_core_internet_gateway.ibmss_internet_gateway.id}"
    }
}


resource "oci_core_nat_gateway" "ibmss_nat_gateway" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.ibmss_vcn.id}"
  display_name   = "ibmss_nat_gateway"
}


resource "oci_core_route_table" "PrivateRouteTable" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.ibmss_vcn.id}"
  display_name   = "PrivateRouteTableForComplete"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = "${oci_core_nat_gateway.ibmss_nat_gateway.id}"
    
  }
}

resource "oci_core_security_list" "PublicSubnet" {
    compartment_id = "${var.compartment_ocid}"
    display_name = "Public Subnet"
    vcn_id = "${oci_core_virtual_network.ibmss_vcn.id}"
    egress_security_rules = [{
        destination = "0.0.0.0/0"
        protocol = "6"
    }]
    egress_security_rules = [{
        destination = "${var.VPC-CIDR}"
        protocol = "1"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 22
            "min" = 22
        }
        protocol = "6"
        source = "0.0.0.0/0"
    }]
    
    ingress_security_rules = [{
        protocol = "6"
	source = "${var.VPC-CIDR}"
    }]
    /* For ping traffic between nodes */
    ingress_security_rules = [{
        protocol = "1"
        source = "${var.VPC-CIDR}"
        icmp_options {
            #Required
            type = "0"

            #Optional
            code = "0"
        }
    }]
    ingress_security_rules = [{
        protocol = "1"
        source = "${var.VPC-CIDR}"
        icmp_options {
            #Required
            type = "8"

            #Optional
            code = "0"
        }
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 80
            "min" = 80
        }
        protocol = "6"
        source = "0.0.0.0/0"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 443
            "min" = 443
        }
        protocol = "6"
        source = "0.0.0.0/0"
    }]
}



resource "oci_core_security_list" "PrivateSubnet" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "Private"
  vcn_id         = "${oci_core_virtual_network.ibmss_vcn.id}"

  egress_security_rules = [{
    destination = "0.0.0.0/0"
    protocol    = "all"
  }]

  egress_security_rules = [{
    protocol    = "all"
    destination = "${var.VPC-CIDR}"
  }]

  ingress_security_rules = [{
    protocol = "6"
    source   = "${var.VPC-CIDR}"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "${var.VPC-CIDR}"
  }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 8850
            "min" = 8850
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 80
            "min" = 80
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 443
            "min" = 443
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]
    # Used by PostgreSQL database.
    ingress_security_rules = [{
        tcp_options {
            "max" = 8060
            "min" = 8060
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 8061
            "min" = 8061
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 9000
            "min" = 8000
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]
    ingress_security_rules = [{
        tcp_options {
            "max" = 27009
            "min" = 27000
        }
        protocol = "6"
        source = "${var.VPC-CIDR}"
    }]

}




## Publicly Accessable Subnet Setup

resource "oci_core_subnet" "public" {
  count = "3"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  cidr_block = "${cidrsubnet(var.VPC-CIDR, 8, count.index)}"
  display_name = "public_${count.index}"
  compartment_id = "${var.compartment_ocid}"
  vcn_id = "${oci_core_virtual_network.ibmss_vcn.id}"
  route_table_id = "${oci_core_route_table.RouteForComplete.id}"
  security_list_ids = ["${oci_core_security_list.PublicSubnet.id}"]
  dhcp_options_id = "${oci_core_virtual_network.ibmss_vcn.default_dhcp_options_id}"
  dns_label = "public${count.index}"
}

## Private Subnet Setup 

resource "oci_core_subnet" "private" {
  count                      = "3"
  availability_domain        = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1],"name")}"
  cidr_block                 = "${cidrsubnet(var.VPC-CIDR, 8, count.index+3)}"
  display_name               = "private_${count.index}"
  compartment_id             = "${var.compartment_ocid}"
  vcn_id                     = "${oci_core_virtual_network.ibmss_vcn.id}"
  route_table_id             = "${oci_core_route_table.PrivateRouteTable.id}"
  security_list_ids          = ["${oci_core_security_list.PrivateSubnet.id}"]
  dhcp_options_id            = "${oci_core_virtual_network.ibmss_vcn.default_dhcp_options_id}"
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "private${count.index}"
}
