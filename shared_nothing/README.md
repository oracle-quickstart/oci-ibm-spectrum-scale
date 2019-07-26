# IBM Spectrum Scale on OCI
This Terrrafom template deploys an IBM Spectrum Scale distributed parallel file system on Oracle Cloud Infrastructure (OCI) using shared nothing architecture.


# High Level Architecture
The template creates all the required infrastucture (virtual network, nat gateway, securitylist, compute, Block volume etc.) as well as installs and configures IBM Spectrum Scale Data Management software.    

You can choose to build the parallel  file system using just Block Volumes or highly performant local NVMe disk (DenseIO shapes) or use both to create a data tier solution which delivers high performance as well as economical.   

The solution can be deployed across 2 Availability domains (AD) (set DataReplica parameter to 2) or in a single AD. 


![](../images/01-shared-nothing-architecture.png)

## IBM Spectrum Scale Data Management license 
This template assumes you already have purchased a license from IBM and have downloaded the software.  The software needs to be stored on a server which is accessible from the servers created by this template in OCI.  For example: you can save the software in OCI Object Storage bucket and create pre-authenticated request to use in your template.  



## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).


## Clone the Terraform template
Now, you'll want a local copy of this repo.  You can make that with the commands:

    git clone https://github.com/oci-quickstart/oci-ibm-spectrum-scale.git
    cd oci-ibm-spectrum-scale/shared_nothing
    ls



## Update variables.tf file (optional)
This is optional, but you can update the variables.tf to change compute shapes to use for servers, dataReplica, # of NSD disks, # of NSD and Compute nodes and and various other values. 


## Deployment & Post Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan && terraform apply


## Terraform apply - output 

![](../images/02-tf-apply.png)

## Output for various GPFS commands

![](../images/03-mm-commands.png)



