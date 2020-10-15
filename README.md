# oci-ibm-spectrum-scale
These are Terraform modules that deploy IBM Spectrum Scale (GPFS) distributed parallel file system on [Oracle Cloud Infrastructure (OCI)](https://cloud.oracle.com/en_US/cloud-infrastructure).   These were developed jointly by [Re-Store](https://www.re-store.net/) and Oracle Cloud team.

On OCI, you can deploy Spectrum Scale using all the below architecture

- Network Shared Disk (NSD) Server model -  **Recommended**
- Direct Attached Storage model
- Shared Nothing model 
- Erasure Code Edition 

This templates uses the **Network Shared Disk (NSD) Server model** to deploy IBM Spectrum Scale. Please follow the instructions in [network_shared_disk_server_model](network_shared_disk_server_model)  folders to deploy.  To deploy other architecures, reach out to pinkesh.valdria@oracle.com .

## IBM Spectrum Scale
IBM Spectrum Scale is a high-performance, highly available, clustered file system and associated management software, available on a variety of platforms. IBM Spectrum Scale can scale in several dimensions, including performance (bandwidth and IOPS), capacity, and number of nodes* (instances) that can mount the file system. IBM Spectrum Scale addresses the needs of applications whose performance (or performance-to-capacity ratio) demands cannot be met by traditional scale-up storage systems; and IBM Spectrum Scale is therefore deployed for many I/O-demanding enterprise applications that require high
performance or scale. IBM Spectrum Scale provides various configuration options, access methods (including traditional POSIX-based file access), and many features such as snapshots, compression, and encryption. 

This Quick Start automates the deployment of IBM Spectrum Scale on OCI for users who require highly available access to a shared namespace across multiple instances with good performance, without requiring an in-depth knowledge of IBM Spectrum Scale. 

## IBM Spectrum Scale Software Download  
This template is designed to work with the following editions: 

      Spectrum Scale Data Management Edition
      Spectrum Scale Developer Edition -  Free for upto 12TB Storage 
      Spectrum Scale Data Access Edition


Please download the Free developer edition of Spectrum Scale software binary from [IBM website](https://www.ibm.com/sg-en/marketplace/scale-out-file-and-object-storage/purchase).  The software needs to be stored on a server which is accessible from the file servers created by this template in OCI.  For example: you can save the software in private secure OCI Object Storage bucket and create pre-authenticated request to use in your template.

If you already have license for Spectrum Scale,  then you can download it from [here](https://www.ibm.com/support/fixcentral/swg/selectFixes?parent=Software%20defined%20storage&product=ibm/StorageSoftware/IBM+Spectrum+Scale&release=All&platform=Linux+64-bit,x86_64&function=all)


## Next Step
1. If your goal is to do a POC, we recommend deploying both Storage Server nodes and Client nodes together using instructions in **[network_shared_disk_server_model](network_shared_disk_server_model)** folders to deploy, including pre-requisites.

2. If your goal is to manage the Storage server nodes and Client nodes seperately (for production like setup), then follow the below steps
   - Create Storage Nodes only cluster using Terraform template in **[network_shared_disk_server_model](network_shared_disk_server_model)** folder.  Make sure to set the client node count to zero.   
   - Create "Clients only" cluster using Terraform template in **[clients_only_cluster](clients_only_cluster)** folder to provision client nodes to mount the filesystem.  

3. If you have any questions,  reach out to me at pinkesh.valdria@oracle.com 
