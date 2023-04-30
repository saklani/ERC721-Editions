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
        virtual
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
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721Test is DSTestPlus {
    MockERC721 token;

    function setUp() public {
        token = new MockERC721(address(this), "Token", "TKN", "https://example.com", 100, 2);
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
        assertEq(token.baseURI(), "https://example.com");
        assertEq(token.mintPrice(), 100);
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

    function testApprove() public {
        token.internalMint(address(this), 1337);
        token.approve(address(0xBEEF), 1337);
        assertEq(token.getApproved(1337), address(0xBEEF));
    }

    function testApproveUnmintedError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNMINTED()"));
        token.approve(address(0xBEEF), 1337);
    }

    function testApproveUnauthorizedError() public {
        token.internalMint(address(this), 1337);
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

        token.internalMint(from, 1337);

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

        token.internalMint(from, 1337);

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

        token.internalMint(from, 1337);

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
        address r = address(new NonERC721Recipient());
        emit log_address(r);
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), r, 1337);
    }

    function testSafeTransferFromToNonERC721RecipientWithDataError() public {
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(new NonERC721Recipient()), 1337, "testing 123");
    }

    function testSafeTransferFromToRevertingERC721Recipient() public {
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 1337);
    }

    function testSafeTransferFromToRevertingERC721RecipientWithDataError() public {
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(new RevertingERC721Recipient()), 1337, "testing 123");
    }

    function testSafeTransferFromToERC721RecipientWithWrongReturnDataError() public {
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 1337);
    }

    function testSafeTransferFromToERC721RecipientWithWrongReturnDataWithDataError() public {
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeTransferFrom(address(this), address(new WrongReturnDataERC721Recipient()), 1337, "testing 123");
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.internalMint(from, 1337);

        hevm.prank(from);
        token.approve(address(this), 1337);

        token.transferFrom(from, address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromSelf() public {
        token.internalMint(address(this), 1337);

        token.transferFrom(address(this), address(0xBEEF), 1337);

        assertEq(token.getApproved(1337), address(0));
        assertEq(token.ownerOf(1337), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        address from = address(0xABCD);

        token.internalMint(from, 1337);

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
        token.internalMint(address(0xCAFE), 1337);
        hevm.expectRevert(abi.encodeWithSignature("NOT_OWNER()"));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testTransferFromToZeroError() public {
        token.internalMint(address(this), 1337);
        hevm.expectRevert(abi.encodeWithSignature("ZERO_ADDRESS()"));
        token.transferFrom(address(this), address(0), 1337);
    }

    function testTransferFromNotOwnerError() public {
        token.internalMint(address(0xFEED), 1337);
        hevm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        token.transferFrom(address(0xFEED), address(0xBEEF), 1337);
    }

    function testInternalMint() public {
        token.internalMint(address(0xBEEF), 1337);
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(1337), address(0xBEEF));
    }

    function testInternalMintToZeroRevert() public {
        hevm.expectRevert(abi.encodeWithSignature("ZERO_ADDRESS()"));
        token.internalMint(address(0), 1337);
    }

    function testInternalMintDoubleMintRevert() public {
        token.internalMint(address(0xBEEF), 1337);
        hevm.expectRevert(abi.encodeWithSignature("ALREADY_MINTED()"));
        token.internalMint(address(0xBEEF), 1337);
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
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(new NonERC721Recipient()), 1337);
    }

    function testSafeMintToNonERC721RecipientWithDataError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(new NonERC721Recipient()), 1337, "testing 123");
    }

    function testSafeMintToRevertingERC721RecipientError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(new RevertingERC721Recipient()), 1337);
    }

    function testSafeMintToRevertingERC721RecipientWithDataError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(new RevertingERC721Recipient()), 1337, "testing 123");
    }

    function testSafeMintToERC721RecipientWithWrongReturnDataError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(new WrongReturnDataERC721Recipient()), 1337);
    }

    function testSafeMintToERC721RecipientWithWrongReturnDataWithDataError() public {
        hevm.expectRevert(abi.encodeWithSignature("UNSAFE_RECIPIENT()"));
        token.safeMint(address(new WrongReturnDataERC721Recipient()), 1337, "testing 123");
    }
}
