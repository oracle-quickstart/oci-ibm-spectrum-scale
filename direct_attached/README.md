# IBM Spectrum Scale on OCI
This Terrrafom template deploys an IBM Spectrum Scale on Oracle Cloud Infrastructure (OCI) using direct attached architecture for data only storage disks. 



# High Level Architecture
The template creates all the required infrastucture (virtual network, nat gateway, securitylist, compute, Block volume etc.) as well as installs and configures IBM Spectrum Scale Data Management software.    

The solution can be deployed in a single AD using block volumes. 


![](../images/04-direct-attached-architecture.png)


## IBM Spectrum Scale Data Management license 
This template assumes you already have purchased a license from IBM and have downloaded the software.  The software needs to be stored on a server which is accessible from the servers created by this template in OCI.  For example: you can save the software in OCI Object Storage bucket and create pre-authenticated request to use in your template.  



## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).


## Clone the Terraform template
Now, you'll want a local copy of this repo.  You can make that with the commands:

    git clone https://github.com/oci-quickstart/oci-ibm-spectrum-scale.git
    cd oci-ibm-spectrum-scale/direct_attached
    ls



## Update variables.tf file (optional)
This is optional, but you can update the variables.tf to change compute shapes to use for servers, # of Meta data NSD disks, # of disks to store data only, Compute nodes and and various other values. 


## Deployment & Post Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan && terraform apply


