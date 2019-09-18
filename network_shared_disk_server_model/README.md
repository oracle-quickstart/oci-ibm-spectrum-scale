# IBM Spectrum Scale on OCI
This Terrrafom template deploys an IBM Spectrum Scale distributed parallel file system on Oracle Cloud Infrastructure (OCI) using Network Shared Disk (NSD) Server model architecture.


## Network Shared Disk (NSD) Server model architecture
The template creates all the required infrastucture (virtual network, nat gateway, securitylist, compute, Block volume etc.) as well as installs and configures IBM Spectrum Scale Data Management software.  The solution can be deployed across 2 Availability domains (AD) (set DataReplica parameter to 2) or in a single AD. 

### Single AD 
![](../images/network_shared_disk_server_model/01-single-AD-architecture.png)

## Multiple AD
![](../images/network_shared_disk_server_model/01-two-AD-architecture.png)

## IBM Spectrum Scale Data Management license 
This template assumes you already have purchased a license from IBM and have downloaded the software.  The software needs to be stored on a server which is accessible from the servers created by this template in OCI.  For example: you can save the software in OCI Object Storage bucket and create pre-authenticated request to use in your template.  



## Prerequisites
First off you'll need to do some pre deploy setup.  That's all detailed [here](https://github.com/oracle/oci-quickstart-prerequisites).


## Clone the Terraform template
Now, you'll want a local copy of this repo.  You can make that with the commands:

    git clone https://github.com/oracle/oci-quickstart-ibm-spectrum-scale.git
    cd oci-quickstart-ibm-spectrum-scale/network_shared_disk_server_model
    ls



## Update variables.tf file (optional)
This is optional, but you can update the variables.tf to change compute shapes to use for NSD servers, dataReplica, # of NSD disks, # of NSD and client nodes and and various other values. 


## Deployment & Post Deployment

Deploy using standard Terraform commands

        terraform init && terraform plan && terraform apply


## Terraform apply - output 

![](../images/network_shared_disk_server_model/02-tf-apply.png)

## Output for various GPFS commands

![](../images/network_shared_disk_server_model/03-mm-commands.png)

## Spectrum Scale Management GUI Interface

### Metrics
![](../images/network_shared_disk_server_model/04-gui-charts.png)

### Dashboard
![](../images/network_shared_disk_server_model/05-gui-dashboard.png)

### Throughput
![](../images/network_shared_disk_server_model/06-gui-throughput.png)


