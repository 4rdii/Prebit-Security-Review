# Prebit.io Smart Contracts Deployment and Security Review

## Introduction

This repository contains the deployment of the smart contracts for [Prebit.io](https://learn.prebit.io/docs/prebit-introduction), a global hub for decentralized market projections. Prebit.io offers a secure, blockchain-based platform for predicting Bitcoin prices and rewards users for accurate and near-accurate predictions. The platform is designed to be user-friendly and easy to use.

## Project Details

Prebit.io operates on the Binance Smart Chain and stands out among its binary (up or down) prediction counterparts with its hourly price forecasting feature. This feature is specifically tailored for the platform and is the focus of this security review.

## Smart Contract Addresses

The following are the addresses of the deployed smart contracts on the Binance Smart Chain:

- **MainPrebit SmartContract**: [`0x287437ee50bf2a246282c5fcb7dc8107f47fda6c`](https://bscscan.com/address/0x287437ee50bf2a246282c5fcb7dc8107f47fda6c)
 - Main Smart Contract of this project.
- **Referral Contract**: [`0x9a8AE3Be63Fc293ce1bC934010DcD0132B6585B0`](https://bscscan.com/address/0x9a8AE3Be63Fc293ce1bC934010DcD0132B6585B0)
 - Referral Contract of this project, contains the process of new referral generation.
- **Injector Contract**: [`0x9a8AE3Be63Fc293ce1bC934010DcD0132B6585B0`](https://bscscan.com/address/0x9a8AE3Be63Fc293ce1bC934010DcD0132B6585B0)
 - This represents the older version of the MainPrebit SmartContract. It serves as the input argument for the newer version, facilitating the migration of remaining funds to the updated version.
- **Precard bonus Token**: [`0xdf1a5FaA82D6d61f86D1dF4fa777Ef597bF69080`](https://bscscan.com/address/0xdf1a5FaA82D6d61f86D1dF4fa777Ef597bF69080)
 - This contract defines the precard bonus token.

## Security Review

The security review of the hourly price forecasting feature is specifically tailored to this platform. Due to the lack of publicly available code and the direct use of deployed smart contracts, the review focuses on the analysis of the deployed contracts on the Binance Smart Chain.

## Executive Summary of Findings

The security review of the Prebit.io smart contracts, specifically focusing on the `MainPrebit` smart contract, has identified several critical vulnerabilities that pose significant risks to the protocol and its users. These vulnerabilities, if exploited, could lead to severe consequences, including the potential for a rug pull, the reliance on manual BTC price input, and issues related to manual contract deployment and prebit management. These issues could compromise the integrity and reliability of the protocol.

| Severity | number of issues found |
| -------- | ---------------------- |
| High     | 2                      |
| Medium   | 2                      |
| Low      | 0                      |
| Info     | 0                      |
| Total    | 4                      |

### Potential for Rug Pull via `MainPrebit::migrateToNewVersion` Function

The `migrateToNewVersion` function within the `MainPrebit` smart contract could be exploited to execute a rug pull. This function, if not properly secured or audited, allows the contract owner to withdraw funds from the contract without returning them to the users. The potential for a rug pull through this function poses a significant risk to the protocol and its users, leading to a loss of trust in the platform. This could also have legal and financial implications for the project, as well as reputational damage. The recommended mitigation strategy involves conducting a thorough audit of the function and implementing safeguards to prevent unauthorized access or manipulation.

### Manual BTC Price Input Issue

The `MainPrebit::executeDrawFinalPrice` function relies on manual input for the BTC price, which poses a risk of severe malfunction if the price is not entered correctly. This manual input method introduces several risks and challenges, including the potential for inaccuracies in the prediction rounds, increased potential for human error, and limitations in the protocol's ability to adapt to real-time market conditions. The recommended mitigation strategy involves implementing a price oracle, such as Chainlink Price Feeds, to ensure that the BTC price is accurately and reliably fetched from a trusted source.

### Manual Contract Deployment Issue

The MainPrebit SmartContracts are deployed manually without the use of a deployer contract. This approach may inadvertently lead to a centralized protocol, as it does not provide a standardized or automated method for deploying new contract versions or instances. The manual deployment process introduces several risks and challenges, including potential for human error, deployment issues, and security risks. The recommended mitigation strategy involves implementing a deployer contract that automates the deployment process, ensuring consistency and reducing the risk of human error.

### Manual Prebit Management Issue

The process of ending the current prebits and starting the next prebit is manually managed by the operator address. This manual approach lacks automation and efficiency, potentially leading to delays or errors in the prediction rounds. The manual management of prebits can introduce several risks and challenges, including potential for human error, delays in the prediction rounds, and limitations in the protocol's scalability and flexibility. The recommended mitigation strategy involves implementing automation protocols, such as Chainlink Automation, for managing prebits, ensuring efficiency and reliability of the prediction rounds.

### Recommendations

To address these vulnerabilities, the project should conduct a comprehensive audit of the `MainPrebit::migrateToNewVersion` function and ensure that it is securely implemented. Additionally, the project should implement a price oracle for the `MainPrebit::executeDrawFinalPrice` function to enhance the protocol's accuracy and reliability. Implementing a deployer contract for automating the deployment process and automation protocols for managing prebits will help to secure the protocol against potential exploits and ensure the integrity and reliability of the platform.

The findings underscore the importance of thorough security audits, the implementation of robust safeguards, and the adoption of automated systems to mitigate risks associated with smart contracts. By addressing these vulnerabilities, Prebit.io can enhance its security posture, build trust with its users, and ensure the long-term sustainability and success of its platform.


## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

have foundry installed: [Foundry Installation](https://book.getfoundry.sh/getting-started/installation)
### Clone the Repository

Open your terminal and clone the repository using the following command:

```
git clone https://github.com/4rdii/Prebit-Security-Review.git
cd Prebit-Security-Review
```
## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

## Contributing

Contributions are welcome. Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

## Contact

If you have any questions or need further clarification, feel free to contact us at:

- Email: agh1994@gmail.com