// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./ERC721.sol";

contract Edition is ERC721 {
    /*----------------------------------------------------------------*
     |                             EVENTS                             |
     *----------------------------------------------------------------*/

    event PriceChange(uint256 amount);
    event Mint(address indexed to, uint256 indexed tokenId);
    event Withdraw(uint256 amount);

    /*----------------------------------------------------------------*
     |                             ERRORS                             |
     *----------------------------------------------------------------*/

    error WITHDRAW_FAILED();

    /*----------------------------------------------------------------*
     |                            METADATA                            |
     *----------------------------------------------------------------*/

    address private _owner;

    // the current owner of the contract
    function owner() public view returns (address) {
        return _owner;
    }

    // the current mint price for this edition
    uint256 private _mintPrice;

    function mintPrice() public view returns (uint256) {
        return _mintPrice;
    }

    // the current mint limit for this edition
    uint256 private _mintLimit;

    function mintLimit() public view returns (uint256) {
        return _mintLimit;
    }

    string private _uri;

    function baseURI() public view returns (string memory) {
        return _uri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert UNMINTED();
        return _uri;
    }

    function contractURI() public view returns (string memory) {
        return _uri;
    }

    /*----------------------------------------------------------------*
     |                   TOKEN ID ISSUER/TRACKER                      |
     *----------------------------------------------------------------*/

    function _incrementTokenId() internal {
        unchecked {
            // Cannot overflow unless _value >= (2^256 - 1), which isn't reasonable.
            _tokenId++;
        }
    }

    uint256 internal _tokenId;

    /*----------------------------------------------------------------*
     |                          CONSTRUCTOR                           |
     *----------------------------------------------------------------*/

    constructor(
        address owner_,
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 mintPrice_,
        uint256 mintLimit_
    ) ERC721(name_, symbol_) {
        _owner = owner_;
        _mintPrice = mintPrice_;
        _mintLimit = mintLimit_;
        _uri = uri_;
    }

    /*----------------------------------------------------------------*
     |                           MODIFIERS                            |
     *----------------------------------------------------------------*/
    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert UNAUTHORIZED();
        }
        _;
    }

    /*----------------------------------------------------------------*
     |                          MINT LOGIC                            |
     *----------------------------------------------------------------*/

    /// @notice Mints a new NFT with `tokenId` for the address `to`. It makes sure that when the receiving address
    ///  is a smart contract it doesn't lock the NFT.
    /// @dev External function to mint tokens, also increments `tokenId`. This function should be used when minting.
    /// @param to The minting address
    function mint(address to) external payable {
        if (msg.value < _mintPrice) {
            revert NOT_ENOUGH_ETH();
        }
        if (_mintLimit <= _tokenId) {
            revert MINT_LIMIT();
        }
        _safeMint(to, _tokenId);
        emit Mint(to, _tokenId);
        _incrementTokenId();
    }

    /*----------------------------------------------------------------*
     |                         UPDATE LOGIC                           |
     *----------------------------------------------------------------*/

    /// @notice Update mint price of the contract
    /// @dev Lets the owner of the contract update the mint limit.
    function updateMintPrice(uint256 newPrice) external onlyOwner {
        _mintPrice = newPrice;
        emit PriceChange(newPrice);
    }

    /*----------------------------------------------------------------*
     |                        WITHDRAW LOGIC                          |
     *----------------------------------------------------------------*/

    /// @notice Withdraw the proceeds from contract.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success,) = _owner.call{value: amount}("");
        if (!success) {
            revert WITHDRAW_FAILED();
        }
        emit Withdraw(amount);
    }

    /*----------------------------------------------------------------*
     |                         UPDATE LOGIC                           |
     *----------------------------------------------------------------*/

    /// @notice Update metadata of the contract
    /// @dev Lets the owner of the contract update the metadata update the URI of the NFT,
    ///  will be removed in a future version.
    function updateURI(string calldata uri) external onlyOwner {
        _uri = uri;
    }
}
