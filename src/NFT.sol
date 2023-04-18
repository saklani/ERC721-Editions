// SPDX-License-Identifier: AGPL-3.0

pragma solidity >=0.8.0;


contract NFT is Ownable, PullPayment {
    string public uri;
    uint256 public mintPrice;
    uint256 private tokenId = 0;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _mintPrice
    ) ERC721(_name, _symbol) {
        uri = _uri;
        mintPrice = _mintPrice;
    }

    function tokenURI(
        uint256
    ) public view virtual override returns (string memory) {
        return uri;
    }

    function mint() external payable {
        require(msg.value >= mintPrice, "Mint price not matched")
        _safeMint(msg.sender, tokenId);
        tokenId++;
    }
}
