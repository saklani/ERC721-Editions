// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "./TokenIssuer.sol";

/**
 * @title ERC721 with Metadata Extension
 * @author saklani
 * @dev A gas efficient implementation of ERC721
 */

contract ERC721 {
    /*----------------------------------------------------------------*
     |                             EVENTS                             |
     *----------------------------------------------------------------*/

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*----------------------------------------------------------------*
     |                             ERRORS                             |
     *----------------------------------------------------------------*/
    error NOT_OWNER();
    error UNAUTHORIZED();
    error UNMINTED();
    error UNSAFE_RECIPIENT();
    error ZERO_ADDRESS();

    /*----------------------------------------------------------------*
     |                            METADATA                            |
     *----------------------------------------------------------------*/

    string private _name;

    function name() public view returns (string memory) {
        return _name;
    }

    string private _symbol;

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    string private _uri;

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert UNMINTED();
        return _uri;
    }

    uint256 private immutable _mintPrice;

    function mintPrice() public view returns (uint256) {
        return _mintPrice;
    }
    /*----------------------------------------------------------------*
     |                   TOKEN ID ISSUER/TRACKER                      |
     *----------------------------------------------------------------*/

    using TokenIssuer for TokenIssuer.TokenId;

    TokenIssuer.TokenId _tokenId;

    /*----------------------------------------------------------------*
     |                          CONSTRUCTOR                           |
     *----------------------------------------------------------------*/

    constructor(string memory name_, string memory symbol_, string memory uri_, uint256 mintPrice_) {
        _name = name_;
        _symbol = symbol_;
        _uri = uri_;
        _mintPrice = mintPrice_;
    }
    /*----------------------------------------------------------------*
     |                            BALANCE                             |
     *----------------------------------------------------------------*/

    mapping(address => uint256) private _balanceOf;

    /// @notice Count all NFTs assigned to address `owner`
    /// @dev Zero Address NFTs are invalid and revert.
    /// @param owner An address for the balance query
    /// @return Number of NFTs owned by `owner`, possibly zero
    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ZERO_ADDRESS();
        return _balanceOf[owner];
    }

    /*----------------------------------------------------------------*
     |                           OWNERSHIP                            |
     *----------------------------------------------------------------*/

    mapping(uint256 => address) private _ownerOf;

    /// @notice Find the owner of an NFT by the `tokenId`
    /// @dev Zero address indicates the NFT is not minted, and hence, reverts.
    /// @param tokenId The identifier for an NFT
    /// @return owner The address of the `owner` of the NFT
    function ownerOf(uint256 tokenId) public view returns (address owner) {
        if ((owner = _ownerOf[tokenId]) == address(0)) revert UNMINTED();
    }

    /*----------------------------------------------------------------*
     |                    APPROVAL STORAGE/LOGIC                      |
     *----------------------------------------------------------------*/

    mapping(uint256 => address) private _getApproved;

    mapping(address => mapping(address => bool)) public _isApprovedForAll;

    /// @notice Set the approved address for an NFT
    /// @dev Zero address indicates no approved address.
    ///  Only works if `msg.sender` is the current NFT owner, or
    ///  an approved address. Otherwise reverts.
    /// @param operator The new approved NFT operator address
    /// @param tokenId The NFT to approve
    function approve(address operator, uint256 tokenId) public {
        address owner = _ownerOf[tokenId];
        if (!(msg.sender == owner || _isApprovedForAll[owner][msg.sender])) {
            revert UNAUTHORIZED();
        }

        _getApproved[tokenId] = operator;
        emit Approval(_ownerOf[tokenId], operator, tokenId);
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Reverts if `tokenId` is not a valid NFT.
    /// @param tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 tokenId) external view returns (address) {
        if (_ownerOf[tokenId] == address(0)) revert UNMINTED();
        return _getApproved[tokenId];
    }

    /// @notice Check if an address is an approved NFT operator for another address' NFT
    /// @param owner The NFT owner address
    /// @param operator The NFT operator address
    /// @return True if `operator` is an approved operator for `owner`, false otherwise
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _isApprovedForAll[owner][operator];
    }

    /// @notice Set approval for a third party ("operator") to manage all of `msg.sender`'s assets
    /// @dev The function allows multiple operators per owner.
    /// @param operator Address to add to the set of authorized operators
    /// @param approved True if the operator is to be approved, false to revoke approval
    function setApprovalForAll(address operator, bool approved) public {
        _isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /*----------------------------------------------------------------*
     |                        TRANSFER LOGIC                          |
     *----------------------------------------------------------------*/
    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Reverts unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param from The current owner of the NFT
    /// @param to The new owner
    /// @param tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external payable {
        transferFrom(from, to, tokenId);
        if (
            !(
                to.code.length == 0
                    || ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, data)
                        == ERC721TokenReceiver.onERC721Received.selector
            )
        ) {
            revert UNSAFE_RECIPIENT();
        }
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param from The current owner of the NFT
    /// @param to The new owner
    /// @param tokenId The NFT to transfer
    function safeTransferFrom(address from, address to, uint256 tokenId) external payable {
        transferFrom(from, to, tokenId);
        if (
            !(
                to.code.length == 0
                    || ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, "")
                        == ERC721TokenReceiver.onERC721Received.selector
            )
        ) {
            revert UNSAFE_RECIPIENT();
        }
    }

    /// @notice Transfer ownership of an NFT
    ///
    ///  THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    ///
    /// @dev Reverts if even one of the following condition fails,
    ///  1. `tokenId` is a valid NFT
    ///  2. `from` is the current owner.
    ///  3. `to` is not the zero address.
    ///  4. `msg.sender` is the current owner, or
    ///     `msg.sender` is an authorized operator, or
    ///     `msg.sender` is a approved address for this NFT,
    /// @param from The current owner of the NFT
    /// @param to The new owner
    /// @param tokenId The NFT to transfer
    function transferFrom(address from, address to, uint256 tokenId) public {
        if (_ownerOf[tokenId] == address(0)) {
            revert UNMINTED();
        }
        if (from != _ownerOf[tokenId]) {
            revert NOT_OWNER();
        }

        if (to == address(0)) {
            revert ZERO_ADDRESS();
        }

        if (!(msg.sender == from || _isApprovedForAll[from][msg.sender] || msg.sender == _getApproved[tokenId])) {
            revert UNAUTHORIZED();
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            --_balanceOf[from];
            ++_balanceOf[to];
        }

        _ownerOf[tokenId] = to;

        delete _getApproved[tokenId];

        emit Transfer(from, to, tokenId);
    }

    /*----------------------------------------------------------------*
     |                         ERC165 LOGIC                           |
     *----------------------------------------------------------------*/

    /*----------------------------------------------------------------*
     |                          MINT LOGIC                            |
     *----------------------------------------------------------------*/
}

abstract contract ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
