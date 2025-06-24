## **SCuBA PowerBI Integration Steps**

### **Supported Scenarios**

This guide covers **two primary scenarios**:

1. **PowerBI with Virtual Network Gateway:**
   - Configure PowerBI to use a Virtual Network Gateway to access data from the ScubaConnect storage account.

2. **PowerBI Desktop Direct Access:**
   - Use PowerBI Desktop to retrieve and publish data directly to a PowerBI workspace. If the report needs to be viewed by others this is the ideal option. If others don't need to view the report, see below.
   - You could also keep the data local and not publish to a PowerBI workspace.

> [!NOTE]
> **Virtual Network Gateway (Scenario 1) is not available in GCC environments.**<br>
> It is supported only in Commercial and GCCHigh.
> [Limitations](https://learn.microsoft.com/en-us/data-integration/vnet/overview#limitations)

### **Pre-Requisites**
Ensure the following requirements are met before proceeding to avoid setup issues.

1. **Virtual Network Gateway Requirements**
   > **Note:** The Virtual Network Gateway option is only available in Commercial and GCCHigh environments. It is not supported in GCC.
   - [Register resource provider](https://learn.microsoft.com/en-us/data-integration/vnet/create-data-gateways#step-1-register-microsoftpowerplatform-as-a-resource-provider)
     - `Microsoft.PowerPlatform`
   - [Subnet delegation](https://learn.microsoft.com/en-us/data-integration/vnet/create-data-gateways#step-2-associate-the-subnet-to-microsoft-power-platform)
     - `Microsoft.PowerPlatform/vnetaccesslinks`
   - [License Requirements](https://learn.microsoft.com/en-us/data-integration/vnet/overview#limitations)
   - [PowerBI Desktop application](https://www.microsoft.com/en-us/download/details.aspx?id=58494&msockid=101dc2aa8ee969a80209d6378f076840)

2. **Requirements for GCC Environments**
   - [PowerBI Desktop application](https://www.microsoft.com/en-us/download/details.aspx?id=58494&msockid=101dc2aa8ee969a80209d6378f076840)

---

### **General Setup Steps**

1. **Download and Import the PowerBI Report**
   - Download the PowerBI report from the repository and import it into PowerBI Desktop.
     - [Path to Download](https://github.com/cisagov/ScubaConnect/blob/main/m365/powerbi/SCuBA%20M365%20Report%20(Azure%20Blob%20Storage).pbix)

2. **Modify the Data Sources**
   - From the **Home** tab, select **Transform data** then **Data source settings**.
     - Highlight the Azure Blob Storage path and select **Change Source**.
       - Enter your blob storage account name and select **OK**.
     - Highlight the Azure Blob Storage path and select **Edit Permissions**.
       - Under **Credentials**, select **Edit**.
         - Provide an Account key (found under **Security + Networking** > **Access Keys** in the storage account).
         - Change Privacy level to **Organizational**.
         - Verify the report updates with the correct data by selecting **Refresh** (to the right of **Transform data**).

3. **Create a PowerBI Workspace**
   - Log in to the appropriate portal and select **Workspaces** > **New workspace**.
     - Commercial: https://app.powerbi.com
     - GCC: https://app.powerbigov.us
     - GCCHigh: https://app.high.powerbigov.us
   - Name the workspace **ScubaConnect** and select **Save**.

4. **Publish the Report**
   - From the **Home** tab, select **Publish**.
     - Select **Save** if prompted.
     - Select **ScubaConnect** as the destination, then select **Select**.
     - Use the hyperlink to view the report in the workspace.

5. **Follow on steps**
   - If you are in a **GCCHigh or Commercial** environment, continue to [Virtual Network Gateway Setup (Commercial & GCCHigh)](#virtual-network-gateway-setup-commercial--gcchigh).
   - If you are in a **GCC** environment, continue to [GCC Environment Steps](#gcc-environment-steps).

---

### **Virtual Network Gateway Setup (Commercial & GCCHigh)**

Follow the [General Setup Steps](#general-setup-steps) above, then:

> [!IMPORTANT]
> Ensure that you have reviewed and completed the pre-requisites before creating the gateway.

1. [Create a VNet data gateway](https://learn.microsoft.com/en-us/data-integration/vnet/create-data-gateways#step-3-create-a-vnet-data-gateway)

2. **Enable the Newly Created Gateway under Semantic Models Settings**
   - From your workspace, select the appropriate Semantic model and select the **...** then **Settings**.
     - Expand **Gateway and cloud connections**.
     - Enable the gateway by toggling the radio button under **Use an On-premises or VNet data gateway**.
     - Where you see **maps to**, select **Add to VNet**.
     - Create a new virtual network connection:
       - **Connection Name:** `ScubaConnect_Gateway`
       - **Connection type:** `Azure Blob Storage`
       - **Account:** `StorageAccountName`
       - **Domain:** `blob.core.windows.net`
       - **Authentication Method:** `oauth`
       - **Privacy Level:** `Organizational`
       > **Note:** If OAuth does not work as the authentication method, select **key** and enter the key from your storage account.
   - From your workspace, select the appropriate Semantic model and select the **...** then **Settings**.
     - Select the hyperlink labeled **View semantic model**.
     - Under **Lineage**, select **Open workspace Lineage**.
     - Select your **Azure Blob Storage** and verify that the connection status states **Connection successful**.

3. **Create a Refresh Schedule**
   - Select the **...** for Semantic model then **Settings**.
     - Expand **Refresh** and enable **Configure a refresh schedule**.
     - Set to the default (daily) or adjust as needed.
     - Select **Apply**.

---

### **GCC Environment Steps**

Follow the [General Setup Steps](#general-setup-steps) above.

> [!NOTE]
> The following steps are only required if ScubaConnect was deployed with a **Virtual Network**.

1. Ensure your PowerBI Desktop system's IP Address is allowed in the Storage Account network rules.
     - [Steps to Add IP](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security?tabs=azure-portal#managing-ip-network-rules)

---
