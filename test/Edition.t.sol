// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import {DSTestPlus} from "./DSTestPlus.sol";
import {DSInvariantTest} from "./DSInvariantTest.sol";

import {Edition} from "../src/Edition.sol";

contract EditionTest is DSTestPlus {
    Edition token;

    function setUp() public {
        token = new Edition(address(this), "Token", "TKN", "http://example.com", 100, 2);
    }

    function invariantMetadata() public {
        assertEq(token.owner(), address(this));
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.mintLimit(), 2);
    }

    function testBalanceOfZeroAddressError() public {
        hevm.expectRevert(abi.encodeWithSignature("ZERO_ADDRESS()"));
        token.balanceOf(address(0));
    }

    function testOwnerOfUnmintedError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNMINTED()"));
        token.ownerOf(1337);
    }

    function testMint() public {
        address to = address(0xBEEF);
        token.mint{value: 1000}(to);
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(0), address(0xBEEF));
    }

    function testMintInsufficientETHRevert() public {
        address to = address(0xBEEF);
        uint256 value = token.mintPrice() - 1;
        hevm.expectRevert(abi.encodeWithSignature("NOT_ENOUGH_ETH()"));
        token.mint{value: value}(to);
    }

    function testMintMintLimitRevert() public {
        address to = address(0xBEEF);
        uint256 value = token.mintPrice();
        token.mint{value: value}(to);
        token.mint{value: value}(to);
        hevm.expectRevert(abi.encodeWithSignature("MINT_LIMIT()"));
        token.mint{value: value}(to);
    }
}
