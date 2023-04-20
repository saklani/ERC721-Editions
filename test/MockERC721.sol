// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "../src/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(string memory _name, string memory _symbol, string memory _uri, uint256 _mintPrice)
        ERC721(_name, _symbol, _uri, _mintPrice)
    {}

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId, bytes memory data) public virtual {
        _safeMint(to, tokenId, data);
    }
}
