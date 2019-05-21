# IBM Spectrum Scale on OCI
This Terrrafom template deploys an IBM Spectrum Scale distributed parallel file system on Oracle Cloud Infrastructure (OCI).

IBM Spectrum Scale is a high-performance, highly available, clustered file system and associated management software, available on a variety of platforms. IBM Spectrum Scale can scale in several dimensions, including performance (bandwidth and IOPS), capacity, and number of nodes* (instances) that can mount the file system. IBM Spectrum Scale addresses the needs of applications whose performance (or performance-to-capacity ratio) demands cannot be met by traditional scale-up storage systems; and IBM Spectrum Scale is therefore deployed for many I/O-demanding enterprise applications that require high
performance or scale. IBM Spectrum Scale provides various configuration options, access methods (including traditional POSIX-based file access), and many features such as snapshots, compression, and encryption. Note that IBM Spectrum Scale is not itself an application in the traditional sense, but instead provides the storage infrastructure for
applications, and it’s expected that such applications will be installed on the instances
provisioned by this Quick Start.

This Quick Start automates the deployment of IBM Spectrum Scale on OCI for users who require highly available access to a shared name space across multiple instances with good performance, without requiring an in-depth knowledge of IBM Spectrum Scale. 


# High Level Architecture
The template creates all the required infrastucture (virtual network, nat gateway, securitylist, compute, Block volume etc.) as well as installs and configures IBM Spectrum Scale Data Management software.    

You can choose to build the parallel  file system using just Block Volumes or highly performant local NVMe disk (DenseIO shapes) or use both to create a data tier solution which delivers high performance as well as economical.   

The solution can be deployed across 2 Availability domains (AD) (set DataReplica parameter to 2) or in a single AD. 



![](./images/IBM_Spectrum_Scale_Architecture.png)

## IBM Spectrum Scale Data Management license 
This template assumes you already have purchased a license from IBM and have downloaded the software.  The software needs to be stored on a server which is accessible from the servers created by this template in OCI.  For example: you can save the software in OCI Object Storage bucket and create pre-authenticated request to use in your template.  



## Prerequisites
In addition to an active tenancy on OCI, you will need a functional installation of Terraform, and an API key for a privileged user in the tenancy.  See these documentation links for more information:

[Getting Started with Terraform on OCI](https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/terraformgetstarted.htm)

[How to Generate an API Signing Key](https://docs.cloud.oracle.com/iaas/Content/API/Concepts/apisigningkey.htm#How)

Once the pre-requisites are in place, you will need to copy the templates from this repository to where you have Terraform installed.


## Clone the Terraform template
Now, you'll want a local copy of this repo.  You can make that with the commands:

    git clone https://github.com/pvaldria/oci-ibm-spectrum-scale_v2.git
    cd oci-ibm-spectrum-scale_v2
    ls


## Update Template Configuration
Update environment variables in config file: [env-vars](https://github.com/pvaldria/oci-ibm-spectrum-scale-v2/blob/master/env-vars)  to specify your OCI account details like tenancy_ocid, user_ocid, compartment_ocid and source this file prior to installation, either reference it in your .rc file for your shell's or run the following:

        source env-vars

## Update variables.tf file (optional)
This is optional, but you can update the variables.tf to change compute shapes to use for servers, dataReplica, # of NSD disks, # of NSD and Compute nodes and and various other values. 


## Deployment & Post Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan && terraform apply


## Terraform apply - output 

![](./images/tf_apply.png)

## Output for various GPFS commands

![](./images/mm_commands.png)



