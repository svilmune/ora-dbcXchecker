# **Exadata Discovery Script**

## 📌 **Overview**

This script provides detailed information about **Exadata Infrastructure, VM Clusters, DB Homes, and Databases** in **Oracle Cloud Infrastructure (OCI)**. It queries OCI resources using the **OCI CLI** and formats the output for easy readability.

## 🔹 **Features**

- 🏗️ **Fetches Exadata Infrastructure** details, including compute and storage configurations.
- 💻 **Retrieves VM Clusters, DB Homes, and Databases**.
- 🖥️ **Lists DB Nodes and associated network details**.
- 🚀 **Supports filtering with ****\`--nodbinfo\`**** to exclude DB Homes and Databases**.
- ☁️ **Works with both OCI CLI and OCI Cloud Shell**.

## 🔑 **Prerequisites**

To run this script, you need:

### **1️⃣ OCI CLI Installed and Configured**

- Follow the [OCI CLI Installation Guide](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) to install.
- Ensure you have a valid authentication profile set up (`~/.oci/config`).

### **2️⃣ Required IAM Permissions**

- \`\` read access to query **Exadata resources** including Infrastructure, VM Clusters and Databases.
- \`\` read access to fetch **OCI networking details**.

### **3️⃣ OCI Cloud Shell (Optional)**

- You can run this script directly from [OCI Cloud Shell](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cloudshell.htm) **without installing anything locally**.
- This requires OCI Cloud Shell policies to your user group in OCI.

## 🚀 **Usage**

The script supports querying Exadata Infrastructure with **specific Exadata Infra OCID**.

### **🛠️ Running the Script**

#### **Example 1: Fetch Exadata Infra by OCID**

```sh
./ora-dbxchecker.sh --dbtype=exadata --ocid=<infra_ocid>
```

#### **Example 2: Skip DB Homes & Databases**

```sh
./ora-dbxchecker.sh --dbtype=exadata --ocid=<infra_ocid> --nodbinfo
```

## ⚙️ **Parameters**

| **Parameter** | **Description**                                     |
| ------------- | --------------------------------------------------- |
| `--dbtype`    | **Required.** Must be `exadata`.                    |
| `--ocid`      | **Exadata Infrastructure OCID** to query.           |
| `--nodbinfo`  | **Optional** flag to **skip DB Homes & Databases**. |

## 📊 **Example Output**

```
============================================================================================
Exadata Cloud Deployment Report - Sat  1 Mar 2025 08:15:27 EST
============================================================================================

Exadata Cloud Infrastructure: Exadata-Infra | Shape: Exadata.X9M | Created: 22-Jul-2024
Compute: 2 Nodes | 252 OCPUs
Storage: 3 Nodes | Storage Size: 192.0 TB | Storage Server Version: 24.1.8.0.0.250208
Customer Contacts: simo@thatfinnishguy

============================================================================================
  Cloud VM Cluster: ExaCS1 Version: 22.1.30.0.0.241204 Cluster State: AVAILABLE
============================================================================================
  OCPUs: 10 | Memory: 1000 GB
  License: BRING_YOUR_OWN_LICENSE | DATA DISKGROUP PCT: 80%
  SCAN DNS: exacl1.subnet.vcn.oraclevcn.com
  SCAN IPs: 10.1.1.3, 10.1.1.4, 10.1.1.5
  SCAN LISTENER PORT: 1521 TCPS: 2484
  Network Security Groups: N/A
  Cluster Name: exacl1
  Cluster Storage Size: 55.0 TB
  Client Subnet: subnet CIDR: 10.1.1.0/24
  Backup Subnet: backup-subnet CIDR: 10.1.2.0/24
  GI VERSION: 19.24.0.0.0
  Created: 23-Jul-2024
  -------------------------------------------------------------------------------------------
      DB Node Details:
  -------------------------------------------------------------------------------------------
       exal1 (IP1: 10.1.1.45, IP2: 10.1.1.55) | exal2 (IP1: 10.1.1.56, IP2: 10.1.1.53)
  -------------------------------------------------------------------------------------------
  DATABASE DETAILS
  -------------------------------------------------------------------------------------------
    DB Home: TFG_DBHome_19c (Version: 19.24.0.0.0)
  -------------------------------------------------------------------------------------------
      Database: TFG1 Status: AVAILABLE
      Backups: Enabled: N/A | Full Backup: SUNDAY

      Connection Strings:
        cdbDefault: <CONNECTION STRING>
        cdbIpDefault: <CONNECTION STRING>

      PDB: PRDOID01
      PDB STATE: AVAILABLE | PDB OPEN MODE: READ_ONLY

      PDB Connection Strings:
          pdbDefault: <CONNECTION STRING>
          pdbIpDefault: <CONNECTION STRING>
```

## ⚠️ **Notes**

- 🛑 The script **only supports**  Exadata Cloud Service** model right now.
- ❌ If you encounter errors, verify your **IAM permissions** and **OCI CLI authentication settings**.
- 🛠️ For troubleshooting, enable **debug mode** in OCI CLI (not yet working):
  ```sh
  oci --debug db cloud-exa-infra get --cloud-exa-infra-id <infra_ocid>
  ```

## 📜 **License**

This project is licensed under the **MIT License**.

---

🚀 **Report any bugs!**

