// SPDX-License-Identifier: AGPL-3.0

pragma solidity >=0.8.0;

/**
 * @title TokenIssuer
 * @author Shaurya Saklani (@saklani)
 * @dev Provides a counter that can only be incremented for issuing ERC721 ids.
 */
library TokenIssuer {
    struct TokenId {
        uint256 _value;
    }

    function current(TokenId storage tokenId) external view returns (uint256) {
        return tokenId._value;
    }

    function increment(TokenId storage tokenId) external {
        unchecked {
            // Cannot overflow unless _value >= (2^256 - 1), which isn't reasonable.
            ++tokenId._value;
        }
    }
}
