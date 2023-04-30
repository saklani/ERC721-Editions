// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./ERC721.sol";

contract Edition is ERC721 {
    /*----------------------------------------------------------------*
     |                             EVENTS                             |
     *----------------------------------------------------------------*/

    event PriceChange(uint256 amount);
    event Mint(address indexed to, uint256 indexed tokenId);

    /*----------------------------------------------------------------*
     |                            METADATA                            |
     *----------------------------------------------------------------*/
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
    ) ERC721(owner_, name_, symbol_, uri_) {
        _mintPrice = mintPrice_;
        _mintLimit = mintLimit_;
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
}
