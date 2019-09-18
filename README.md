# oci-quickstart-ibm-spectrum-scale
These are Terraform modules that deploy IBM Spectrum Scale (GPFS) distributed parallel file system on [Oracle Cloud Infrastructure (OCI)](https://cloud.oracle.com/en_US/cloud-infrastructure).   These were developed jointly by [Re-Store](https://www.re-store.net/) and Oracle.

These templates deploy IBM Spectrum Scale Data Management Edition using "Network Shared Disk (NSD) Server model/cluster topology. Please follow the instructions in [network_shared_disk_model](network_shared_disk_model)  folders to deploy.

## IBM Spectrum Scale
IBM Spectrum Scale is a high-performance, highly available, clustered file system and associated management software, available on a variety of platforms. IBM Spectrum Scale can scale in several dimensions, including performance (bandwidth and IOPS), capacity, and number of nodes* (instances) that can mount the file system. IBM Spectrum Scale addresses the needs of applications whose performance (or performance-to-capacity ratio) demands cannot be met by traditional scale-up storage systems; and IBM Spectrum Scale is therefore deployed for many I/O-demanding enterprise applications that require high
performance or scale. IBM Spectrum Scale provides various configuration options, access methods (including traditional POSIX-based file access), and many features such as snapshots, compression, and encryption. Note that IBM Spectrum Scale is not itself an application in the traditional sense, but instead provides the storage infrastructure for
applications, and it’s expected that such applications will be installed on the instances
provisioned by this Quick Start.

This Quick Start automates the deployment of IBM Spectrum Scale on OCI for users who require highly available access to a shared name space across multiple instances with good performance, without requiring an in-depth knowledge of IBM Spectrum Scale. 

## IBM Spectrum Scale Data Management License 
This template assumes you already have purchased a license from IBM and have downloaded the software.  The software needs to be stored on a server which is accessible from the servers created by this template in OCI.  For example: you can save the software in OCI Object Storage bucket and create pre-authenticated request to use in your template.
