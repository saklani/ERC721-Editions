// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/**
 * @title ERC721 with Metadata Extension
 * @author saklani (modified)
 * @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
 * @dev A gas efficient implementation of ERC721
 */

abstract contract ERC721 {
    /*----------------------------------------------------------------*
     |                             EVENTS                             |
     *----------------------------------------------------------------*/

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*----------------------------------------------------------------*
     |                             ERRORS                             |
     *----------------------------------------------------------------*/

    error ALREADY_MINTED();
    error MINT_LIMIT();
    error NOT_OWNER();
    error NOT_ENOUGH_ETH();
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

    function tokenURI(uint256 tokenId) public view virtual returns (string memory);

    /*----------------------------------------------------------------*
     |                          CONSTRUCTOR                           |
     *----------------------------------------------------------------*/

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    /*----------------------------------------------------------------*
     |                            BALANCE                             |
     *----------------------------------------------------------------*/

    mapping(address => uint256) internal _balanceOf;

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

    mapping(uint256 => address) internal _ownerOf;

    /// @notice Find the owner of an NFT by the `tokenId`
    /// @dev Zero address indicates the NFT is not minted, and hence, reverts.
    /// @param tokenId The identifier for an NFT
    /// @return owner The address of the `owner` of the NFT
    function ownerOf(uint256 tokenId) external view returns (address owner) {
        if ((owner = _ownerOf[tokenId]) == address(0)) revert UNMINTED();
    }

    /*----------------------------------------------------------------*
     |                    APPROVAL STORAGE/LOGIC                      |
     *----------------------------------------------------------------*/

    mapping(uint256 => address) private _getApproved;

    mapping(address => mapping(address => bool)) private _isApprovedForAll;

    /// @notice Set the approved address for an NFT
    /// @dev Zero address indicates no approved address.
    ///  Requirement:
    ///  `msg.sender` should current NFT owner or `msg.sender` is an approved address.
    /// @param operator The new approved NFT operator address
    /// @param tokenId The NFT to approve
    function approve(address operator, uint256 tokenId) external {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert UNMINTED();
        if (!(msg.sender == owner || _isApprovedForAll[owner][msg.sender])) {
            revert UNAUTHORIZED();
        }

        _getApproved[tokenId] = operator;
        emit Approval(owner, operator, tokenId);
    }

    /// @notice Get the approved address for a single NFT
    /// @dev
    ///  Requirement:
    ///  `tokenId` MUST be a valid NFT.
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
     |                          MINT LOGIC                            |
     *----------------------------------------------------------------*/

    /// @dev Reverts if even one of the following condition fails,
    ///  1. `to` address should not be zero address.
    ///  2. `tokenId` should not be minted.
    ///
    /// @param to The minting address
    /// @param tokenId The NFT to transfer
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ZERO_ADDRESS();
        }

        if (_ownerOf[tokenId] != address(0)) {
            revert ALREADY_MINTED();
        }

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    /// @dev Calls the internal `_mint` function.
    ///  When transfer is complete, this function checks if `_to` is a smart contract (code size > 0).
    ///  If so, it calls `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param to The minting address
    /// @param tokenId The NFT to transfer
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /// @dev Same as other `_safeMint` function with an extra data parameter.
    /// @param to The minting address
    /// @param tokenId The NFT to transfer
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /*----------------------------------------------------------------*
     |                        TRANSFER LOGIC                          |
     *----------------------------------------------------------------*/

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param from The current owner of the NFT
    /// @param to The new owner
    /// @param tokenId The NFT to transfer
    function _safeTransferFrom(address from, address to, uint256 tokenId) internal {
        _safeTransferFrom(from, to, tokenId, "");
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev
    ///  Requirement:
    ///  1. `msg.sender` is the current owner, an authorized operator, or the approved address for this NFT.
    ///  2. `from` is the current owner
    ///  3. `to` is not the zero address.
    ///  4. `tokenId` is minted.
    ///
    ///  When transfer is complete, this function checks if `to` is a smart contract (code size > 0).
    ///  If so, it calls `onERC721Received` on `to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param from The current owner of the NFT
    /// @param to The new owner
    /// @param tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function _safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /// @notice Transfer ownership of an NFT
    ///
    ///  THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    ///
    /// @dev
    /// Requirement:
    ///  1. `tokenId` is a valid NFT
    ///  2. `from` is the current owner.
    ///  3. `to` is not the zero address.
    ///  4. `msg.sender` is the current owner, or
    ///     `msg.sender` is an authorized operator, or
    ///     `msg.sender` is a approved address for this NFT,
    /// @param from The current owner of the NFT
    /// @param to The new owner
    /// @param tokenId The NFT to transfer
    function _transferFrom(address from, address to, uint256 tokenId) internal {
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
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;

        delete _getApproved[tokenId];

        emit Transfer(from, to, tokenId);
    }

    /*----------------------------------------------------------------*
     |                         ERC165 LOGIC                           |
     *----------------------------------------------------------------*/

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x80ac58cd // ERC165 Interface ID for ERC721
            || interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /*----------------------------------------------------------------*
     |                     RECIPIENT CHECK LOGIC                       |
     *----------------------------------------------------------------*/

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (
            to.code.length != 0
                && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, data)
                    != ERC721TokenReceiver.onERC721Received.selector
        ) {
            revert UNSAFE_RECIPIENT();
        }
    }
}

interface ERC721TokenReceiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}
