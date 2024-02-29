---
title: Protocol Audit Report
author: Ardeshir Gholami
date: 27 feb 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries Protocol Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Ardeshir Gholami](https://github.com/4rdii)
Lead Auditors: 
- Ardeshir Gholami

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
    - [\[H-1\] Storing the password on-chain makes it visible to anyone](#h-1-storing-the-password-on-chain-makes-it-visible-to-anyone)
    - [\[H-2\] `PasswordStore::setPassword` has no access controls, meaning a nonowner can change the password](#h-2-passwordstoresetpassword-has-no-access-controls-meaning-a-nonowner-can-change-the-password)
- [Informational](#informational)
    - [\[I-1\] `PasswordStore::getPassword` Function Misleading Comments](#i-1-passwordstoregetpassword-function-misleading-comments)

# Protocol Summary


[Prebit Introduction](https://learn.prebit.io/docs/prebit-introduction)
```Let's take a deep look into the platform
PREBIT is a trusted global hub for decentralized market projections.
It offers a secure, blockchain-based platform for predicting Bitcoin prices and rewards users for accurate and near-accurate predictions.
The platform is very user-friendly and easy to use.
```
This review is specifically tailored to the hourly price forecasting feature of the platform, which operates on the Binance Smart Chain and stands out among its binary (up or down) prediction counterpart.
Because the project website did not provide the necessary information, and my search results did not yield any GitHub repositories for the project, the code used in the project directly comes from their deployed smart contracts on the Binance SmartChain. The addresses are as follows:

- MainPrebit SmartContract: : [0x287437ee50bf2a246282c5fcb7dc8107f47fda6c]
  - Main Smart Contract of this project.
- Referral Contract: [0x9a8AE3Be63Fc293ce1bC934010DcD0132B6585B0]
  - Referral Contract of this project, contains the process of new referral generation.
- Injector Contract: [0x9a8AE3Be63Fc293ce1bC934010DcD0132B6585B0] 
  - This represents the older version of the MainPrebit SmartContract. It serves as the input argument for the newer version, facilitating the migration of remaining funds to the updated version.
- Precard bonus Token: [0xdf1a5FaA82D6d61f86D1dF4fa777Ef597bF69080]
  - This contract defines the precard bonus token.

# Disclaimer

I made all effort to find as many vulnerabilities in the code in the given time period, but hold no responsibilities for the findings provided in this document. A security audit by me is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details

**The findings described in this document correspond the following commit hash:**
```
72805e737081ab0d64862acb90e5785288d81677
```
## Scope
``` 
src/  
    Main.sol
    PrebitReferrals.sol
```


## Roles
Here's a concise and clear summary of the roles and their functions within the context of the MainPrebit Contract:

1. Owner: The Owner has exclusive access to all contract functions, utilizing the `MainPrebit::onlyOwner` modifier to ensure full control over the contract's operations.
2. Operator: The Operator manages the prediction rounds(`MainPrebit::onlyOperator`), with the ability to end ongoing rounds (`MainPrebit::executeDrawFinalPrice`) and initiate new ones (`MainPrebit::startNextPrebit`).
3. User: A User, also referred to as a buyer, purchases prediction tickets, commonly known as precards, to participate in the prediction market.
4. Parent: The Parent is the individual who referred the User to the protocol, playing a crucial role in the referral system that may offer incentives or benefits.
5. Injector: The Injector represents the older version of the MainPrebit Contract. It is utilized specifically for migrating any remaining funds to the newer version of the contract, ensuring a smooth transition and continuity of operations.

This summary outlines the key roles within the MainPrebit Contract ecosystem, highlighting the responsibilities and functions of each party involved.
# Executive Summary

## Issues found

| Severity | number of issues found |
| -------- | ---------------------- |
| High     | 2                      |
| Medium   | 0                      |
| Low      | 0                      |
| Info     | 1                      |
| Total    | 0                      |

# Findings
# High
### [H-1] Storing the password on-chain makes it visible to anyone

**Description:** All data stored chain is visible to anyone and can be read directly from the blockchain. the `PasswordStore::s_password` var is intended to be private and only visible through the `PasswordStore::getPassword` function, which is intended to be only called by the owner of the contract.
We show one such method of reading any data off-chain below.

**Impact:**

**Proof of Concept:** (Proof of Code)
1. Create a local chain
```bash
make anvil
```
2. Deploy the contract
```
make deploy
``` 
3. run the storage tool to read storage slots
the password is set in storage slot 1
```
cast storage 0x5FbDB2315678afecb367f032d93F642f64180aa3 1 --rpc-url http://127.0.0.1:8545
```
4. parse it to string from bytes32 
```
ast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
```
**Recommended Mitigation:**
In the audit of the smart contract, a critical security concern regarding the handling of sensitive information was identified, specifically the recording of a password in a private string. This practice poses a significant risk, as it exposes the system to potential unauthorized access and data breaches. Instead of storing passwords directly in the smart contract, it is recommended to implement a more secure and robust authentication mechanism.



### [H-2] `PasswordStore::setPassword` has no access controls, meaning a nonowner can change the password 

**Description:**
The `PasswordStore::setPassword` function within the smart contract is designed to allow users to update their stored password. However, upon review, it was discovered that this function lacks any form of access control. This means that any user, not just the owner of the password, can call this function and change the password stored in the contract. This lack of access control poses a significant security risk, as it allows unauthorized users to potentially gain access to sensitive information or manipulate the system in ways that could compromise its integrity and security.
```javascript
    function setPassword(string memory newPassword) external {
        //n why anyone can set a new password ?
        // @audit Any user can set a new password
        // missing access control
        s_password = newPassword;
        emit SetNetPassword();
    }
```

**Impact:**
The absence of access controls on the PasswordStore::setPassword function could lead to several adverse outcomes. Firstly, it could enable unauthorized users to change passwords without the consent of the original owner, potentially leading to unauthorized access to accounts or sensitive information. Secondly, it could be exploited by malicious actors to disrupt the normal operation of the smart contract or to gain unauthorized access to critical functions or data. This could have far-reaching implications for the security and functionality of the smart contract, affecting not only the immediate operation but also the trust and reliability of the system in the long term.

**Proof of Concept:**
To demonstrate a proof of concept for the vulnerability identified in the PasswordStore::setPassword function using the provided steps, we'll follow a series of commands to interact with a local Ethereum blockchain, deploy a smart contract, and then attempt to change the password from a non-owner's address. This example assumes you have a basic understanding of Ethereum, smart contracts, and the tools mentioned.
add this test to your projects test file:
<details>

```javascript
    function testSetPasswordNotOwner(address randomAddress) public {
        // Attempt to set the password as a non-owner
        string memory expectedPassword = "myNewPassword";
        vm.assume(randomAddress != owner);
        vm.prank(randomAddress);
        passwordStore.setPassword(expectedPassword);

        vm.prank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, expectedPassword);
    }
```
</details>

**Recommended Mitigation:**
To address this vulnerability, it is recommended to implement robust access control mechanisms for the `PasswordStore::setPassword` function. This could involve requiring that only the owner of the password can call this function, or by implementing additional authentication and authorization checks to ensure that only authorized users can change the password. Additionally, consider implementing logging and monitoring to detect and alert on unauthorized access attempts, allowing for quicker response and mitigation of potential security incidents. Regular security audits and penetration testing should also be conducted to identify and address any other potential vulnerabilities in the smart contract.

```javascript
if(msg.sender != s_owner){
    revert PasswordStore__NotOwenr();
    }
```
# Informational

### [I-1] `PasswordStore::getPassword` Function Misleading Comments 

**Description:**
The `PasswordStore::getPassword` function within the smart contract is intended to allow only the owner to retrieve the stored password. However, the function does not accept any parameters, which contradicts the comment that mentions a parameter for the new password. This discrepancy between the function's implementation and its documentation could lead to confusion and potentially expose the password to unauthorized access if developers mistakenly assume the function requires a parameter.

**Impact:**
The natspec is incorrect.

**Proof of Concept:**
**Recommended Mitigation:**
Remove the incorrect natspec line,
```diff
-        * @param newPassword The new password to set.

```
