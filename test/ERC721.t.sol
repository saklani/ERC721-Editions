// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import {DSTestPlus} from "./DSTestPlus.sol";
import {DSInvariantTest} from "./DSInvariantTest.sol";

import {MockERC721} from "./MockERC721.sol";

import {ERC721TokenReceiver} from "../src/ERC721.sol";

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(address _operator, address _from, uint256 _id, bytes calldata _data)
        public
        override
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721Test is DSTestPlus {
    MockERC721 token;

    function setUp() public {
        token = new MockERC721("Token", "TKN");
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
    }

    function testBalanceOfZeroAddressError() public {
        hevm.expectRevert(abi.encodeWithSignature("ZERO_ADDRESS()"));
        token.balanceOf(address(0));
    }

    function testOwnerOfUnmintedError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNMINTED()"));
        token.ownerOf(1337);
    }

    function testApprove() public {
        token.mint(address(this), 1337);
        token.approve(address(0xBEEF), 1337);
        assertEq(token.getApproved(1337), address(0xBEEF));
    }

    function testApproveUnmintedError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNMINTED()"));
        token.approve(address(0xBEEF), 1337);
    }

    function testApproveUnauthorizedError() public {
        token.mint(address(this), 1337);
        hevm.prank(address(0xABCD));
        hevm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        token.approve(address(0xBEEF), 1337);
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);
        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), 1337, "testing 123");

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), 1337);
        assertBytesEq(recipient.data(), "testing 123");
    }

    function testSafeTransferFromToNonERC721RecipientError() public {
        NonERC721Recipient to = new NonERC721Recipient();
        token.mint(address(this), 1337);
        hevm.expectRevert(bytes(""));
        token.safeTransferFrom(address(this), address(to), 1337);
    }

    function testSafeTransferFromToNonERC721RecipientWithDataError() public {
        NonERC721Recipient to = new NonERC721Recipient();
        token.mint(address(this), 1337);
        hevm.expectRevert(bytes(""));
        token.safeTransferFrom(address(this), address(to), 1337, "testing 123");
    }

    function testSafeTransferFromToRevertingERC721Recipient() public {
        RevertingERC721Recipient to = new RevertingERC721Recipient();
        token.mint(address(this), 1337);
        hevm.expectRevert(bytes(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector))));
        token.safeTransferFrom(address(this), address(to), 1337);
    }

    function testSafeTransferFromToRevertingERC721RecipientWithDataError() public {
        RevertingERC721Recipient to = new RevertingERC721Recipient();
        token.mint(address(this), 1337);
        hevm.expectRevert(bytes(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector))));
        token.safeTransferFrom(address(this), address(to), 1337, "testing 123");
    }

    function testSafeTransferFromToERC721RecipientWithWrongReturnDataError() public {
        WrongReturnDataERC721Recipient to = new WrongReturnDataERC721Recipient();
        token.mint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(to), 1337);
    }

    function testSafeTransferFromToERC721RecipientWithWrongReturnDataWithDataError() public {
        WrongReturnDataERC721Recipient to = new WrongReturnDataERC721Recipient();
        token.mint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(to), 1337, "testing 123");
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        hevm.prank(from);
        token.approve(address(this), 1337);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromSelf() public {
        token.mint(address(this), 1337);

        token.transferFrom(address(this), address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        address from = address(0xABCD);

        token.mint(from, 1337);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromUnmintedError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNMINTED()"));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testTransferFromWrongFromError() public {
        token.mint(address(0xCAFE), 1337);
        hevm.expectRevert(abi.encodeWithSignature("NOT_OWNER()"));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testTransferFromToZeroError() public {
        token.mint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("ZERO_ADDRESS()"));
        token.transferFrom(address(this), address(0), 1337);
    }

    function testTransferFromNotOwnerError() public {
        token.mint(address(0xFEED), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testMint() public {
        token.mint(address(0xBEEF), 1337);
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(1337), address(0xBEEF));
    }

    function testMintToZeroRevert() public {
        hevm.expectRevert(abi.encodeWithSignature("ZERO_ADDRESS()"));
        token.mint(address(0), 1337);
    }

    function testMintDoubleMintRevert() public {
        token.mint(address(0xBEEF), 1337);
        hevm.expectRevert(abi.encodeWithSignature("ALREADY_MINTED()"));
        token.mint(address(0xBEEF), 1337);
    }

    function testSafeMintToEOA() public {
        token.safeMint(address(0xBEEF), 1337);

        assertEq(token.ownerOf(1337), address(address(0xBEEF)));
        assertEq(token.balanceOf(address(address(0xBEEF))), 1);
    }

    function testSafeMintToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), 1337);

        assertEq(token.ownerOf(1337), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.data(), "");
    }

    function testSafeMintToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), 1337, "testing 123");

        assertEq(token.ownerOf(1337), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        assertBytesEq(to.data(), "testing 123");
    }

    function testSafeMintToNonERC721RecipientError() public {
        NonERC721Recipient to = new NonERC721Recipient();
        hevm.expectRevert(bytes(""));
        token.safeMint(address(to), 1337);
    }

    function testSafeMintToNonERC721RecipientWithDataError() public {
        NonERC721Recipient to = new NonERC721Recipient();
        hevm.expectRevert(bytes(""));
        token.safeMint(address(to), 1337, "testing 123");
    }

    function testSafeMintToRevertingERC721RecipientError() public {
        RevertingERC721Recipient to = new RevertingERC721Recipient();
        hevm.expectRevert(bytes(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector))));
        token.safeMint(address(to), 1337);
    }

    function testSafeMintToRevertingERC721RecipientWithDataError() public {
        RevertingERC721Recipient to = new RevertingERC721Recipient();
        hevm.expectRevert(bytes(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector))));
        token.safeMint(address(to), 1337, "testing 123");
    }

    function testSafeMintToERC721RecipientWithWrongReturnDataError() public {
        WrongReturnDataERC721Recipient to = new WrongReturnDataERC721Recipient();
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(to), 1337);
    }

    function testSafeMintToERC721RecipientWithWrongReturnDataWithDataError() public {
        WrongReturnDataERC721Recipient to = new WrongReturnDataERC721Recipient();
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(to), 1337, "testing 123");
    }
}
