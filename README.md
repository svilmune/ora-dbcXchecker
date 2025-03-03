Exadata Discovery Script

Overview

This script provides detailed information about Exadata Infrastructure, VM Clusters, DB Homes, and Databases in Oracle Cloud Infrastructure (OCI). It queries OCI resources using the OCI CLI and formats the output for easy readability.

Features

Fetches Exadata Infrastructure details, including compute and storage configurations.

Retrieves VM Clusters, DB Homes, and Databases.

Lists DB Nodes and associated network details.

Supports filtering with --nodbinfo to exclude DB Homes and Databases.

Works with both OCI CLI and OCI Cloud Shell.

Prerequisites

To run this script, you need:

OCI CLI installed and configured

Follow OCI CLI Installation Guide to install.

Ensure you have a valid authentication profile set up (~/.oci/config).

Required IAM permissions:

DATABASE_READ access to query Exadata resources.

NETWORK_READ access to fetch networking details.

OCI Cloud Shell (Optional)

You can run this script directly from OCI Cloud Shell without installing anything locally.

Usage

Running the Script

The script supports querying Exadata Infrastructure either by Compartment OCID or specific Exadata Infra OCID.

Example 1: Fetch Exadata Infra by OCID

./exadata_discovery.sh --dbtype=exadata --ocid=<infra_ocid>

Example 2: Skip DB Homes & Databases

./exadata_discovery.sh --dbtype=exadata --ocid=<infra_ocid> --nodbinfo

Parameters

Parameter

Description

--dbtype

Required. Must be exadata.

--ocid

Exadata Infrastructure OCID to query.

--nodbinfo

Optional flag to skip DB Homes & Databases.

Example Output

============================================================================================
Exadata Cloud Deployment Report - 29-Feb-2024
============================================================================================

Exadata Infrastructure: MyExaInfra1 | Shape: Exadata.X9M | Created: 15-Feb-2025
Compute: 2 Nodes | 96 OCPUs
Storage: 3 Nodes | Storage Size: 200 TB

============================================================================================
  Cloud VM Cluster: VMCluster1 | Version: 19c | State: AVAILABLE
============================================================================================
  OCPUs: 32 | Memory: 1024 GB
  License: LICENSE_INCLUDED
  Created: 20-Jan-2024
  -------------------------------------------------------------------------------------------
    DB Home: PRODDBHome (Version: 19.17.0.0)
  -------------------------------------------------------------------------------------------
      Database: PRODDB1
      Database: PRODDB2
  -------------------------------------------------------------------------------------------

Notes

The script only supports Exadata Cloud@Customer and Exadata Cloud Service models.

If you encounter errors, verify your IAM permissions and OCI CLI authentication settings.

For troubleshooting, enable debug mode in OCI CLI:

oci --debug db cloud-exa-infra get --cloud-exa-infra-id <infra_ocid>

License

This project is licensed under the MIT License.

🚀 Start using the script now to discover your Exadata infrastructure!

