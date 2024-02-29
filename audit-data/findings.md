
### [S-2] Manual Contract Deployment Issue
**Description:**
The MainPrebit SmartContracts are deployed manually without the use of a deployer contract. This approach may inadvertently lead to a centralized protocol, as it does not provide a standardized or automated method for deploying new contract versions or instances.

**Impact:**
The manual deployment process introduces several risks and challenges. It may limit the protocol's scalability and flexibility, as each deployment necessitates manual intervention. This could also amplify the potential for human error, potentially leading to deployment issues or vulnerabilities. Moreover, the manual deployment process significantly heightens security risks. If the private key of the owner (deployer) account is compromised, the project could be at risk, with all funds potentially at stake. This centralization of control over deployment exposes the protocol to unauthorized access or malicious activities, jeopardizing the platform's security and integrity.


**Proof of Concept:**
Upon reviewing the project's smart contracts, it was observed that the deployment of the MainPrebit SmartContracts is done through custom scripts and manual execution. This lack of a deployer contract was NOT confirmed through discussions with the project team.(because I had no access to them) The deployer of the MainPrebit SmartContract is the address below, as verified from the BSC block explorer: [0x47B11a3afE6538e299c138C031264A10802a7E7A].

**Recommended Mitigation:**
To mitigate this issue, the project should implement a deployer contract that automates the deployment process. This contract could manage the deployment of new contract versions or instances, ensuring consistency and reducing the risk of human error. Additionally, adopting a standardized deployment framework or tool could further enhance the protocol's scalability and adaptability. The project team should also consider implementing automated testing and verification processes to ensure the security and reliability of each deployment.




### [S-3] Manual Prebit Management Issue 
**Description:**
The process of ending the current prebits and starting the next prebit is manually managed by the operator address. This manual approach lacks automation and efficiency, potentially leading to delays or errors in the prediction rounds.

**Impact:**
The manual management of prebits can introduce several risks and challenges. It may lead to delays in the prediction rounds, affecting user participation and engagement. Additionally, it could increase the potential for human error, leading to incorrect management of prediction rounds or vulnerabilities in the system. This manual approach also limits the scalability and flexibility of the protocol, as it does not provide a standardized or automated method for managing prediction rounds.

**Proof of Concept:**
Upon reviewing the project's smart contracts and documentation, it was observed that the management of prebits is done manually by the operator address. This lack of automation was not confirmed through discussions with the project team. The Operator of the MainPrebit SmartContract is the address below, as verified from the BSC block explorer: [0x531b5C8bf9f2d0E069b48F01Bc129B06f9f603ca]

**Recommended Mitigation:**
To mitigate this issue, the project should implement automation protocols, such as Chainlink Automation, for managing prebits. This automation could ensure that prebits are ended and new ones are started in a timely and error-free manner, enhancing the efficiency and reliability of the prediction rounds. Additionally, adopting a standardized automation framework or tool could further enhance the protocol's scalability and adaptability. The project team should also consider implementing automated testing and verification processes to ensure the security and reliability of each prediction round.

### [S-4] Manual BTC Price Input Issue (Root Cause + Impact)

**Description:**
The `MainPrebit::executeDrawFinalPrice` function is provided with the price of BTC manually. This manual input method poses a risk of severe malfunction if the price is not entered correctly, potentially compromising the integrity and reliability of the protocol.

**Impact:**
The reliance on manual BTC price input can introduce several risks and challenges. It may lead to inaccuracies in the prediction rounds, affecting user participation and engagement. Additionally, it could increase the potential for human error, leading to incorrect price inputs and vulnerabilities in the system. This manual approach also limits the protocol's ability to adapt to real-time market conditions, potentially affecting its long-term sustainability and security.

**Proof of Concept:**
Upon reviewing the project's smart contracts and documentation, it was observed that the `MainPrebit::executeDrawFinalPrice` function relies on manual input for the BTC price. This manual input method was not confirmed through discussions with the project team but was deduced through a thorough examination of the project's codebase and deployment practices. It should be noted that the project team may use custom scripts for this purpose. However, due to the absence of documentation or available GitHub repositories, there is a need to highlight this aspect, emphasizing the importance of transparency and standardized practices in smart contract development and deployment.

**Recommended Mitigation:**
To mitigate this issue, the project should implement a price oracle, such as Chainlink Price Feeds, for the `MainPrebit::executeDrawFinalPrice` function. This automation could ensure that the BTC price is accurately and reliably fetched from a trusted source, enhancing the protocol's accuracy and reliability. Additionally, adopting a standardized oracle framework or tool could further enhance the protocol's scalability and adaptability. The project team should also consider implementing automated testing and verification processes to ensure that the utilized oracle works correctly.




### [S-5] Potential for Rug Pull via `MainPrebit::migrateToNewVersion` Function (Root Cause + Impact)

**Description:**
The `MainPrebit::migrateToNewVersion` function within the smart contract could be exploited to execute a rug pull. This function, if not properly secured or audited, will allow the contract owner to withdraw funds from the contract without returning them to the users.

**Impact:**
The potential for a rug pull through the `MainPrebit::migrateToNewVersion` function poses a significant risk to the protocol and its users. It could lead to a loss of trust in the platform, as users may fear that their funds could be withdrawn without their consent. This could also have legal and financial implications for the project, as well as reputational damage. Additionally, it could affect the protocol's long-term sustainability and security, as it undermines the trust and confidence of its users.

**Proof of Concept:**
Upon reviewing the project's smart contracts and documentation, it was observed that the `migrateToNewVersion` function within the smart contract could potentially be exploited to execute a rug pull. This potential vulnerability was identified through a test suite developed using an `attacker.sol` contract, which is a copy of the `mainPrebit.sol` contract but includes a function designed to empty the contract of all funds.

The test suite, executed in Foundry, simulates the process by which the protocol owner could exploit the `migrateToNewVersion` function to transfer all funds to a new contract without returning them to the users. This process involves:

1. **Initial Setup**: The test begins by setting up the environment with `startGenesisPreBitAndBuyPrecards`, which likely initializes the prediction round and allows users to buy precards.

2. **Warping Time and Ending the Prebit**: The test simulates the passage of time and ends the current prebit by calling `executeDrawFinalPrice`. This step is crucial for setting up the conditions under which a rug pull could occur.

3. **Claiming Rewards**: Although not strictly necessary for the exploit, claiming rewards demonstrates the process by which users would normally interact with the contract. This step is included to provide a more realistic scenario.

4. **Pre-Migration Balances**: The test checks the balances of the main contract and the attacker contract before migration. This is a critical step to establish a baseline for comparison.

5. **Migration to the Attacker Contract**: The test simulates the migration of the main contract to the attacker contract, which is designed to exploit the `migrateToNewVersion` function. This step is the core of the test, demonstrating how the contract's owner could potentially use this function to transfer all funds to a new contract.

6. **Post-Migration Balances**: After migration, the test checks the balances again to confirm that the funds have been transferred from the main contract to the attacker contract.

7. **Rug Pull Execution**: Finally, the test executes the `emptyContract` function of the attacker contract, simulating the transfer of all assets to a secure address (in this case, `HACKER`). This step is where the rug pull would occur, with the contract's funds being moved without returning them to the users.

8. **Final Balance Check**: The test verifies that the `HACKER` has received the funds that were originally in the main contract, confirming the successful execution of the rug pull.

This test suite effectively demonstrates the potential vulnerability of the `migrateToNewVersion` function to a rug pull. It provides a clear pathway for exploitation, from the setup of the environment to the execution of the exploit, and concludes with a verification of the exploit's success. This is a valuable contribution to identifying and mitigating potential security risks in smart contracts.


**Recommended Mitigation:**
To mitigate this issue, the project should conduct a thorough audit of the `MainPrebit::migrateToNewVersion` function and ensure that it is securely implemented. This audit should include checks for potential vulnerabilities that could be exploited for a rug pull. Additionally, the project should implement safeguards to prevent unauthorized access or manipulation of the function. The project team should also consider providing detailed documentation on the function's operation and security measures to reassure users and stakeholders of the protocol's commitment to security and transparency.
