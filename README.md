# Why is this repository private? #

|                                       |                                        |
| ------------------------------------- | -------------------------------------- |
| **Repository made private on:**       | Nov 15, 2024                           |
| **Private status approved by:**       | [@h-m-f-t](https://github.com/h-m-f-t) |
| **Private exception reason:**         | Pending BOD release                    |
| **Repository contents:**              | A tool to support a new CISA directive |
| **Planned repository deletion date:** | n/a                            |
| **Responsible contacts:**             | [@chad-CISA](https://github.com/chad-CISA)  |

See our [development guide](https://github.com/cisagov/development-guide#readme)
for more information about our [private repository
policy](https://github.com/cisagov/development-guide/blob/develop/open-source-policy/practice.md#private-repositories).

- - - - -

<!-- above should be deleted once public -->

# ScubaConnect
ScubaConnect is cloud-native infrastructure that automates the execution of assessment tools [ScubaGear](https://github.com/cisagov/ScubaGear) and [ScubaGoggles](https://github.com/cisagov/ScubaGoggles) across multiple tenants from a central location, allowing administrators to maintain consistent and secure configurations

### Target Audience

ScubaConnect is for M365 and GWS administrators who want to streamline the assessment of their tenant environments against CISA Secure Configuration Baselines (SCBs), eliminating the need to manually update, configure, and run ScubaGear and ScubaGoggles.

### Federal Agencies

Following the release of CISA’s [Binding Operational Directive (BOD) 25-01: Implementing Secure Practices for Cloud Services](https://www.cisa.gov/news-events/directives/bod-25-01-implementation-guidance-implementing-secure-practices-cloud-services) on Dec. 17, 2024, which requires Federal Civilian Executive Branch (FCEB) agencies to deploy SCuBA assessment tools for in-scope cloud tenants no later than Friday, April 25, 2025 and begin continuous reporting, agencies can use ScubaConnect to ensure their cloud environments are properly configured and that reports are submitted automatically to CISA. For more information, please refer to the [SCuBA project webpage](https://www.cisa.gov/resources-tools/services/secure-cloud-business-applications-scuba-project) or email scuba@cisa.dhs.gov.

## Overview

ScubaConnect has two managed components for SCuBA’s two current assessment tools: GearConnect (for ScubaGear) and GogglesConnect (for ScubaGoggles).

### Getting Started with GearConnect

All code is provided in terraform for easy installation. For use with [ScubaGear](https://github.com/cisagov/ScubaGear) (Microsoft 365), see [`m365`](m365) directory.

### Getting Started with GogglesConnect

All code is provided in terraform for easy installation. For use with [ScubaGoggles](https://github.com/cisagov/ScubaGoggles) (Google Workspace), see [`gws`](gws) directory.

## Resources

* [BOD 25-01: Implementation Guidance for Implementing Secure Practices for Cloud Services](https://www.cisa.gov/news-events/directives/bod-25-01-implementation-guidance-implementing-secure-practices-cloud-services)
* For FCEB agencies, email scuba@cisa.dhs.gov to gain access to the SCuBA Slack Channel


## Project License

Unless otherwise noted, this project is distributed under the Creative Commons Zero license. With developer approval, contributions may be submitted with an alternate compatible license. If accepted, those contributions will be listed herein with the appropriate license.
