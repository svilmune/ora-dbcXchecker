#!/bin/bash

##################################################################################
# Script Name  : ora-dbxchecker.sh
# Purpose      : This script retrieves details of Exadata Infrastructure and VM Clusters
#                in Oracle Cloud Infrastructure (OCI) and works with DB@Azure and DB@GCP for
#                Exadata.
# Author       : Simo Vilmunen
# Version      : 1.0
# Date         : 28-Feb-2025    
#
# Usage        : ./ora-dbxchecker.sh --dbtype=exadata --ocid=<EXADATA INFRA OCID> [--nodbinfo]
# Example      : To discover Exadata infrastructure details, run:
#               ./ora-dbxchecker.sh --dbtype=exadata --ocid=<EXADATA INFRA OCID> [--nodbinfo]
#                To not print DB Homes & Databases, use --nodbinfo flag.
#
# Notes        :
# - This script only supports "exadata" for now, but can be extended for other DB types.
# - Requires OCI CLI to be configured with appropriate permissions.
#
#   TO-DO add support in near term for OCI DBCS, Autonomous DB and ExaScale.
#   Add support for ECPU models with X11M. 
#   For Exadata Cloud@Customer, I don't have means to test this and add support yet.
##################################################################################

# Function to format date correctly on both Linux and macOS
format_date() {
    local raw_date="$1"

    # Normalize timestamp: Remove milliseconds and convert `+00:00` to `Z`
    raw_date=$(echo "$raw_date" | sed -E 's/\.[0-9]+//; s/\+00:00/Z/')

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: Convert ISO timestamp to DD-MMM-YYYY
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$raw_date" "+%d-%b-%Y" 2>/dev/null || echo "N/A"
    else
        # Linux: Convert using `date -d`
        date -u -d "${raw_date//T/ }" "+%d-%b-%Y" 2>/dev/null || echo "N/A"
    fi
}

# Default: Print DB Homes & Databases
NODBINFO="no"

# Parse command-line arguments
for arg in "$@"; do
    case $arg in
        --dbtype=*)
            DBTYPE="${arg#*=}"
            shift
            ;;
        --ocid=*)
            EXADATA_INFRA_OCID="${arg#*=}"
            shift
            ;;
        --nodbinfo)
            NODBINFO="yes"
            shift
            ;;
        --help)
            echo "Usage: $0 --dbtype=exadata --ocid=<infra_ocid> [--nodbinfo]"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 --dbtype=exadata --ocid=<infra_ocid> [--nodbinfo]"
            exit 1
            ;;
    esac
done


# Validate required arguments
if [[ -z "$DBTYPE" || "$DBTYPE" != "exadata" ]]; then
    echo "Error: --dbtype=exadata is required."
    exit 1
fi

if [[ -z "$EXADATA_INFRA_OCID" ]]; then
    echo "Error: --ocid=<infra_ocid> is required."
    exit 1
fi

EXADATA_INFRA_OCID=$(echo "$EXADATA_INFRA_OCID" | tr -d '[:space:]')

echo "============================================================================================"
echo "Exadata Cloud Deployment Report - $(date)"
echo "============================================================================================"
echo ""

# Fetch Exadata Infrastructure list
EXADATA_INFRA=$(oci db cloud-exa-infra get --cloud-exa-infra-id "$EXADATA_INFRA_OCID" --output json)

if echo "$EXADATA_INFRA" | jq -e '.data' > /dev/null 2>&1; then
    EXA_INFRA_JSON=$(echo "$EXADATA_INFRA" | jq -c '.data')
else
    echo "Error: Unexpected JSON structure or missing 'data' field."
    exit 1
fi

EXA_INFRA_JSON=$(echo "$EXADATA_INFRA" | jq -c '.data')

# Validate JSON structure before using jq
if [[ -z "$EXA_INFRA_JSON" || "$EXA_INFRA_JSON" == "null" ]]; then
    echo "Error: No valid data returned from OCI."
    exit 1
fi

# Extract Exadata Cloud Infrastructure details (handle missing keys safely)
INFRA_ID=$(echo "$EXA_INFRA_JSON" | jq -r '."id" // "N/A"')
INFRA_NAME=$(echo "$EXA_INFRA_JSON" | jq -r '."display-name" // "N/A"')
INFRA_SHAPE=$(echo "$EXA_INFRA_JSON" | jq -r '."shape" // "N/A"')
COMPUTE_COUNT=$(echo "$EXA_INFRA_JSON" | jq -r '."compute-count" // "N/A"')
STORAGE_COUNT=$(echo "$EXA_INFRA_JSON" | jq -r '."storage-count" // "N/A"')
STORAGE_SIZE=$(echo "$EXA_INFRA_JSON" | jq -r '."max-data-storage-in-tbs" // "N/A"')
MAX_CPU_COUNT=$(echo "$EXA_INFRA_JSON" | jq -r '."max-cpu-count" // "N/A"')
STORAGE_SERVER_VERSION=$(echo "$EXA_INFRA_JSON" | jq -r '."storage-server-version" // "N/A"')
COMPARTMENT_OCID=$(echo "$EXA_INFRA_JSON" | jq -r '."compartment-id" // "N/A"')

# Extract and format Exadata Infrastructure creation time
EXA_INFRA_TIME_CREATED=$(echo "$EXA_INFRA_JSON" | jq -r '."time-created" // "N/A"')

if [[ "$EXA_INFRA_TIME_CREATED" != "N/A" && -n "$EXA_INFRA_TIME_CREATED" ]]; then
    EXA_INFRA_TIME_FORMATTED=$(format_date "$EXA_INFRA_TIME_CREATED")
else
    EXA_INFRA_TIME_FORMATTED="N/A"
fi

# Extract Customer Contact Emails
CUSTOMER_CONTACTS=$(echo "$EXA_INFRA_JSON" | jq -r '."customer-contacts"[].email' 2>/dev/null)

if [[ -z "$CUSTOMER_CONTACTS" || "$CUSTOMER_CONTACTS" == "null" ]]; then
    CUSTOMER_CONTACTS="N/A"
fi

echo "Exadata Cloud Infrastructure: $INFRA_NAME | Shape: $INFRA_SHAPE | Created: $EXA_INFRA_TIME_FORMATTED"
echo "Compute: $COMPUTE_COUNT Nodes | $MAX_CPU_COUNT OCPUs"
echo "Storage: $STORAGE_COUNT Nodes | Storage Size: $STORAGE_SIZE TB | Storage Server Version: $STORAGE_SERVER_VERSION"
echo "Customer Contacts: $CUSTOMER_CONTACTS"
echo ""

# Fetch Cloud VM Clusters for the current Exadata Infrastructure
VM_CLUSTERS=$(oci db cloud-vm-cluster list --cloud-exa-infra-id "$INFRA_ID" --compartment-id "$COMPARTMENT_OCID" --output json)

echo "$VM_CLUSTERS" | jq -c '.data[]' | while IFS= read -r vm_json; do
    # Extract Cloud VM Cluster details
    VM_CLUSTER_ID=$(echo "$vm_json" | jq -r '."id" // "N/A"')
    VM_CLUSTER_NAME=$(echo "$vm_json" | jq -r '."display-name" // "N/A"')
    CPU_CORE_COUNT=$(echo "$vm_json" | jq -r '."cpu-core-count" // "N/A"')
    MEMORY=$(echo "$vm_json" | jq -r '."memory-size-in-gbs" // "N/A"')
    CLUSTER_STORAGE_SIZE=$(echo "$vm_json" | jq -r 'if ."data-storage-size-in-tbs" then ."data-storage-size-in-tbs" else "N/A" end')
    NSG_IDS=$(echo "$vm_json" | jq -r 'if ."nsg-ids" then ."nsg-ids" | join(", ") else "N/A" end')
    CLUSTER_HOSTNAME=$(echo "$vm_json" | jq -r 'if .hostname then .hostname else "N/A" end')
    SCAN_DNS_NAME=$(echo "$vm_json" | jq -r 'if ."scan-dns-name" then ."scan-dns-name" else "N/A" end')
    SCAN_PORT=$(echo "$vm_json" | jq -r 'if ."scan-listener-port-tcp" then ."scan-listener-port-tcp" else "N/A" end')
    SCAN_TSL_PORT=$(echo "$vm_json" | jq -r 'if ."scan-listener-port-tcp-ssl" then ."scan-listener-port-tcp-ssl" else "N/A" end')
    GI_VERSION=$(echo "$vm_json" | jq -r '."gi-version" // "N/A"')
    SYSTEM_VERSION=$(echo "$vm_json" | jq -r '."system-version" // "N/A"')
    LICENSE=$(echo "$vm_json" | jq -r '."license-model" // "N/A"')
    DATA_STORAGE_PCT=$(echo "$vm_json" | jq -r '."data-storage-percentage" // "N/A"')
    LIFE_CYCLE_STATE=$(echo "$vm_json" | jq -r '."lifecycle-state" // "N/A"')

    # Extract and format VM Cluster creation time
    VM_CLUSTER_TIME_CREATED=$(echo "$vm_json" | jq -r '."time-created" // "N/A"')

    if [[ "$VM_CLUSTER_TIME_CREATED" != "N/A" && -n "$VM_CLUSTER_TIME_CREATED" ]]; then
        VM_CLUSTER_TIME_FORMATTED=$(format_date "$VM_CLUSTER_TIME_CREATED")
    else
        VM_CLUSTER_TIME_FORMATTED="N/A"
    fi

    # Extract SCAN IP OCIDs (Ensure proper splitting and trimming)
    SCAN_IP_OCIDS=$(echo "$vm_json" | jq -r 'if ."scan-ip-ids" then ."scan-ip-ids" | join("\n") else "N/A" end')

    # Convert SCAN IP OCIDs to actual IP addresses
    SCAN_IPS_ARRAY=()  # Array to store IPs

    if [[ "$SCAN_IP_OCIDS" != "N/A" ]]; then
        # Use a temporary file to store OCIDs
        TEMP_FILE=$(mktemp)
        echo "$SCAN_IP_OCIDS" | tr -d ' ' > "$TEMP_FILE"

        while IFS= read -r scan_ip_ocid; do
            if [[ -n "$scan_ip_ocid" ]]; then  # Ensure OCID is not empty
                ip=$(oci network private-ip get --private-ip-id "$scan_ip_ocid" --query 'data."ip-address"' --raw-output 2>&1)

                # Validate if output is a valid IP (IPv4 format)
                if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    SCAN_IPS_ARRAY+=("$ip")  # Store in array
                else
                    echo "Warning: Invalid IP response: $ip"
                fi
            fi
        done < "$TEMP_FILE"

        rm -f "$TEMP_FILE"  # Clean up temp file

        # Join IPs with commas
        SCAN_IPS=$(printf "%s, " "${SCAN_IPS_ARRAY[@]}")
        SCAN_IPS=${SCAN_IPS%, }  # Remove trailing comma
    else
        SCAN_IPS="N/A"
    fi

  # Extract DB Server OCIDs (Handles both array & object formats)
DB_SERVER_OCIDS=$(echo "$vm_json" | jq -r '."db-servers"[]' 2>/dev/null)

DB_NODE_DETAILS=""

# Fetch DB Node Names using db-node-ids
if [[ -n "$DB_SERVER_OCIDS" && "$DB_SERVER_OCIDS" != "null" ]]; then
    for server_ocid in $DB_SERVER_OCIDS; do
        # Get all DB Node IDs from the DB Server
        DB_NODE_IDS=$(oci db db-server get --db-server-id "$server_ocid" --exadata-infrastructure-id "$INFRA_ID" --query 'data."db-node-ids"' --output json | jq -r '. | join(" ")')

        if [[ -n "$DB_NODE_IDS" && "$DB_NODE_IDS" != "null" ]]; then
            for node_id in $(echo "$DB_NODE_IDS" | tr ' ' '\n'); do
                NODE_JSON=$(oci db node get --db-node-id "$node_id" --query 'data' --output json 2>/dev/null)

                # Extract VM Cluster ID this node belongs to
                NODE_VM_CLUSTER_ID=$(echo "$NODE_JSON" | jq -r '."db-system-id" // empty')

                #echo "DEBUG: DB Node $node_id belongs to VM Cluster: $NODE_VM_CLUSTER_ID"

                # Only include nodes that belong to the current VM Cluster
                if [[ "$NODE_VM_CLUSTER_ID" == "$VM_CLUSTER_ID" ]]; then
                    NODE_NAME=$(echo "$NODE_JSON" | jq -r '."hostname" // "N/A"')
                    VNIC_ID=$(echo "$NODE_JSON" | jq -r '."vnic-id" // "N/A"')
                    VNIC2_ID=$(echo "$NODE_JSON" | jq -r '."vnic2-id" // "N/A"')

                    # Fetch Private IP for VNICs
                    PRIVATE_IP_1="N/A"
                    PRIVATE_IP_2="N/A"

                    if [[ "$VNIC_ID" != "N/A" ]]; then
                        PRIVATE_IP_1=$(oci network vnic get --vnic-id "$VNIC_ID" --query 'data."private-ip"' --raw-output 2>/dev/null)
                    fi

                    if [[ "$VNIC2_ID" != "N/A" ]]; then
                        PRIVATE_IP_2=$(oci network vnic get --vnic-id "$VNIC2_ID" --query 'data."private-ip"' --raw-output 2>/dev/null)
                    fi

                    # Append node info
                    DB_NODE_DETAILS+=" $NODE_NAME (IP1: $PRIVATE_IP_1, IP2: $PRIVATE_IP_2) |"
                fi
            done
        else
            echo "DEBUG: No DB Nodes found for DB Server: $server_ocid"
        fi
    done
    DB_NODE_DETAILS=${DB_NODE_DETAILS%|}  # Remove trailing pipe
else
    echo "DEBUG: No DB Servers found in VM Cluster: $VM_CLUSTER_NAME"
fi

if [[ -z "$DB_NODE_DETAILS" ]]; then
    DB_NODE_DETAILS="N/A"
fi
    # Extract Client & Backup Subnet OCIDs
    CLIENT_SUBNET_OCID=$(echo "$vm_json" | jq -r '."subnet-id" // "N/A"')
    BACKUP_SUBNET_OCID=$(echo "$vm_json" | jq -r '."backup-subnet-id" // "N/A"')

    # Fetch Client Subnet Name & CIDR Block in a Single CLI Call
    CLIENT_SUBNET_NAME="N/A"
    CLIENT_CIDR_BLOCK="N/A"
    if [[ "$CLIENT_SUBNET_OCID" != "N/A" ]]; then
        CLIENT_SUBNET_JSON=$(oci network subnet get --subnet-id "$CLIENT_SUBNET_OCID" --query 'data' --output json 2>/dev/null)
        CLIENT_SUBNET_NAME=$(echo "$CLIENT_SUBNET_JSON" | jq -r '."display-name" // "N/A"')
        CLIENT_CIDR_BLOCK=$(echo "$CLIENT_SUBNET_JSON" | jq -r '."cidr-block" // "N/A"')
    fi

    # Fetch Backup Subnet Name & CIDR Block in a Single CLI Call
    BACKUP_SUBNET_NAME="N/A"
    BACKUP_CIDR_BLOCK="N/A"
    if [[ "$BACKUP_SUBNET_OCID" != "N/A" ]]; then
        BACKUP_SUBNET_JSON=$(oci network subnet get --subnet-id "$BACKUP_SUBNET_OCID" --query 'data' --output json 2>/dev/null)
        BACKUP_SUBNET_NAME=$(echo "$BACKUP_SUBNET_JSON" | jq -r '."display-name" // "N/A"')
        BACKUP_CIDR_BLOCK=$(echo "$BACKUP_SUBNET_JSON" | jq -r '."cidr-block" // "N/A"')
    fi

    echo "============================================================================================"
    echo "  Cloud VM Cluster: $VM_CLUSTER_NAME Version: $SYSTEM_VERSION Cluster State: $LIFE_CYCLE_STATE"
    echo "============================================================================================"
    echo "  OCPUs: $CPU_CORE_COUNT | Memory: $MEMORY GB"
    echo "  License: $LICENSE | DATA DISKGROUP PCT: $DATA_STORAGE_PCT%"
    echo "  SCAN DNS: $SCAN_DNS_NAME"
    echo "  SCAN IPs: $SCAN_IPS"
    echo "  SCAN LISTENER PORT: $SCAN_PORT TCPS: $SCAN_TSL_PORT"
    echo "  Network Security Groups: $NSG_IDS"
    echo "  Cluster Name: $CLUSTER_HOSTNAME"
    echo "  Cluster Storage Size: $CLUSTER_STORAGE_SIZE TB"
    echo "  Client Subnet: $CLIENT_SUBNET_NAME CIDR: $CLIENT_CIDR_BLOCK"
    echo "  Backup Subnet: $BACKUP_SUBNET_NAME CIDR: $BACKUP_CIDR_BLOCK"
    echo "  GI VERSION: $GI_VERSION"
    echo "  Created: $VM_CLUSTER_TIME_FORMATTED"
    echo "  -------------------------------------------------------------------------------------------"
    echo "      DB Node Details:"
    echo "  -------------------------------------------------------------------------------------------"
    echo "      $DB_NODE_DETAILS"
    echo "  -------------------------------------------------------------------------------------------"


    if [[ "$NODBINFO" == "yes" ]]; then
    echo ""
    else
    echo "  DATABASE DETAILS"

    # Fetch Database Homes in the Cloud VM Cluster
    DB_HOMES=$(oci db db-home list --vm-cluster-id "$VM_CLUSTER_ID" --compartment-id "$COMPARTMENT_OCID" --output json)

    # Check if DB_HOMES is empty or null
    if [[ -z "$DB_HOMES" || "$DB_HOMES" == "null" ]]; then
        echo "    No Database Homes found."
    else
        echo "$DB_HOMES" | jq -c '.data[]' | while IFS= read -r db_home_json; do
            # Extract DB Home details (Ensure db-version is always a string)
            DB_HOME_ID=$(echo "$db_home_json" | jq -r '."id" // "N/A"')
            DB_HOME_NAME=$(echo "$db_home_json" | jq -r 'if ."display-name" then ."display-name" else "N/A" end')

            # Handle db-version correctly (force into string)
            DB_VERSION=$(echo "$db_home_json" | jq -r 'if ."db-version" and ."db-version" | type == "number" then ."db-version" | tostring elif ."db-version" then ."db-version" else "N/A" end')

            echo "  -------------------------------------------------------------------------------------------"
            echo "    DB Home: $DB_HOME_NAME (Version: $DB_VERSION)"
            echo "  -------------------------------------------------------------------------------------------"

            # Fetch Databases in the DB Home
            DATABASES=$(oci db database list --vm-cluster-id "$VM_CLUSTER_ID" --compartment-id "$COMPARTMENT_OCID" --output json)

            # Check if DATABASES is empty or null
            if [[ -z "$DATABASES" || "$DATABASES" == "null" ]]; then
                echo "      No Databases found."
            else
                echo "$DATABASES" | jq -c --arg DB_HOME_ID "$DB_HOME_ID" '.data[] | select(."db-home-id" == $DB_HOME_ID)' | while IFS= read -r db_json; do
                    if [[ -z "$db_json" || "$db_json" == "null" ]]; then
                        echo "      Skipping empty database entry."
                        continue
                    fi

                    # Extract Database details (Ensure numeric fields are treated as strings)
                    DB_NAME=$(echo "$db_json" | jq -r '."db-name" // "N/A"')
                    DB_ID=$(echo "$db_json" | jq -r '."id" // "N/A"')
                    DB_LIFECYCLE_STATE=$(echo "$db_json" | jq -r '."lifecycle-state" // "N/A"')
                    BACKUP_ENABLED=$(echo "$db_json" | jq -r '."db-backup-config"."auto-backup-enabled" // "N/A"')
                    FULL_BACKUP_DAY=$(echo "$db_json" | jq -r '."db-backup-config"."auto-full-backup-day" // "N/A"')

                    # Extract connection strings from the nested object
                    CONNECTION_STRINGS=$(echo "$db_json" | jq -r '
                        if ."connection-strings"."all-connection-strings" then 
                            ."connection-strings"."all-connection-strings" | to_entries | map("\(.key): \(.value | tostring)") | join(" | ") 
                        else "N/A" 
                        end')

                    echo "      Database: $DB_NAME Status: $DB_LIFECYCLE_STATE"
                    echo "      Backups: Enabled: $BACKUP_ENABLED | Full Backup: $FULL_BACKUP_DAY"
                    echo ""
                    echo "      Connection Strings:"

                    # Extract each connection string separately and print on a new line
                    echo "$db_json" | jq -r '
                        if ."connection-strings"."all-connection-strings" then 
                            ."connection-strings"."all-connection-strings" | to_entries | map("        \(.key): \(.value | tostring)") | .[]
                        else "        N/A" 
                        end'

                    # Fetch PDBs for this database
                    PDBS=$(oci db pluggable-database list --database-id "$DB_ID" --output json)

                    if [[ -z "$PDBS" || "$PDBS" == "null" ]]; then
                        echo "      No Pluggable Databases (PDBs) found."
                    else
                        echo "$PDBS" | jq -c '.data[]' | while IFS= read -r pdb_json; do
                            if [[ -z "$pdb_json" || "$pdb_json" == "null" ]]; then
                                echo "        Skipping empty PDB entry."
                                continue
                            fi

                            # Extract PDB Name
                            PDB_NAME=$(echo "$pdb_json" | jq -r '."pdb-name" // "N/A"')
                            PDB_ID=$(echo "$pdb_json" | jq -r '."id" // "N/A"')
                            PDB_LIFECYCLE_STATE=$(echo "$pdb_json" | jq -r '."lifecycle-state" // "N/A"')
                            PDB_OPEN_MODE=$(echo "$pdb_json" | jq -r '."open-mode" // "N/A"')
                            # Extract PDB connection strings
                            PDB_CONNECTION_STRINGS=$(echo "$pdb_json" | jq -r '
                                if ."connection-strings"."all-connection-strings" then 
                                    ."connection-strings"."all-connection-strings" | to_entries | map("\(.key): \(.value | tostring)") | join(" | ") 
                                else "N/A" 
                                end')
                            echo ""
                            echo "      PDB: $PDB_NAME"
                            echo "      PDB STATE: $PDB_LIFECYCLE_STATE | PDB OPEN MODE: $PDB_OPEN_MODE"
                            echo ""
                            echo "      PDB Connection Strings:"
                            echo "$pdb_json" | jq -r '
                                if ."connection-strings"."all-connection-strings" then 
                                    ."connection-strings"."all-connection-strings" | to_entries | map("          \(.key): \(.value | tostring)") | .[]
                                else "          N/A" 
                                end'
                        done
                    fi
                done
            fi
        done  # Ends DB Home loop
        fi
        echo "  -------------------------------------------------------------------------------------------"
    fi

done  # Ends Cloud VM Cluster loop