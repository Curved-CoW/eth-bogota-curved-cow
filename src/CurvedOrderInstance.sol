// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";
import "./interfaces/IERC20.sol";
import {GPv2EIP1271} from "./interfaces/ERC1271.sol";
import "./interfaces/ICoWSwapSettlement.sol";
import "./mixins/GPv2Signing.sol";

contract CurvedOrderInstance is EIP1271Verifier, GPv2Signing {
    ICoWSwapSettlement public immutable settlement;
    address private constant vaultRelayer = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public immutable owner;
    IERC20 public immutable sellToken;

    /// @dev The EIP-712 domain name used for computing the domain separator.
    bytes32 private constant DOMAIN_NAME = keccak256("ETH Bogota Curved Order");

    constructor(address owner_, IERC20 _sellToken, ICoWSwapSettlement _settlement) {
        owner = owner_;
        sellToken = _sellToken;
        settlement = _settlement;
        _sellToken.approve(_settlement.vaultRelayer(), type(uint256).max);
    }

    /**
     * @notice isValidSignature returns whether the provider signature and hash are valid. This method is called by GPv2 settlement contract when validating an order for execution
     * @param _hash bytes32 hash of the GPv2Order.Data struct
     * @param _payload encoded payload with metadata including `GPv2Order`, `CurvedOrder`, and `signature`. This is usually referred to as a signature in the EIP, but we're calling it payload here to differentiate between cryptographic signatures which have different meaning. This payload is encoded as follows abi.encoded(GPv2Order,CurvedOrder,bytes32). The bytes32 represents the signature of a signed curved order to verify the order was infact submitted by the LP.
     */
    function isValidSignature(bytes32 _hash, bytes calldata _payload) external view returns (bytes4 magicValue) {
        (GPv2Order.Data memory _gpv2Order, CurvedOrder.Data memory _curvedOrder, bytes memory _curvedOrderSignature) =
            decode(_payload);

        bytes memory msg_bytes = abi.encode(
            _curvedOrder.sellToken,
            _curvedOrder.buyToken,
            _curvedOrder.receiver,
            _curvedOrder.sellAmount,
            _curvedOrder.buyAmount,
            _curvedOrder.validTo,
            _curvedOrder.sellTokenBalance,
            _curvedOrder.buyTokenBalance
        );

        bytes32 msg_hash = keccak256(msg_bytes);

        bytes memory hex_prefix = hex"19457468657265756d205369676e6564204d6573736167653a0a3332";

        msg_hash = keccak256(abi.encodePacked(hex_prefix, msg_hash));

        address recovered_signer = this.ecdsaRecover(msg_hash, _curvedOrderSignature);

        require(GPv2Order.hash(_gpv2Order, domainSeparator) == _hash, "hash doesnt match gpv2order");
        require(CurvedOrder.executionAboveCurve(_gpv2Order, _curvedOrder), "execution not above curve");
        require(recovered_signer == owner, "signature doesnt match owner");

        return GPv2EIP1271.MAGICVALUE;
    }

    /**
     * @notice decode - decodes the payload into GPv2Order, CurvedOrder, and signature to verify the order was submitted by the LP
     * @param _payload bytes contains the encoded payload with metadata including `GPv2Order`, `CurvedOrder`, and `signature`. This is usually referred to as a signature in the EIP, but we're calling it payload here to differentiate between cryptographic signatures. This payload is encoded as follows abi.encoded(GPv2Order,CurvedOrder,bytes). The bytes represents the signature of a signed curved order to verify the order was infact submitted by the LP.
     */
    function decode(bytes calldata _payload)
        public
        pure
        returns (
            GPv2Order.Data memory _gpv2Order,
            CurvedOrder.Data memory _curvedOrder,
            bytes memory _curvedOrderSignature
        )
    {
        (_gpv2Order, _curvedOrder, _curvedOrderSignature) =
            abi.decode(_payload, (GPv2Order.Data, CurvedOrder.Data, bytes));
    }

    /**
     * @notice generateSignature is a helper method used by solver to generate a signature to attach to GPv2Trade
     * @param _gpv2Order GPv2Order.Data created by solver
     * @param _curvedOrder CurvedOrder.Data created by LP / Curved order submitter / owner
     * @param _curvedOrderSignature signature of signed curvedOrder
     */
    function generateSignature(
        GPv2Order.Data calldata _gpv2Order,
        CurvedOrder.Data calldata _curvedOrder,
        bytes calldata _curvedOrderSignature
    ) external view returns (bytes memory signature) {
        bytes memory encodedCurvedOrder = abi.encode(_gpv2Order, _curvedOrder, _curvedOrderSignature);
        signature = abi.encodePacked(address(this), encodedCurvedOrder);
    }

    function withdraw(IERC20 token) public {
        require(msg.sender == owner, "only owner can withdraw");
        token.transfer(owner, token.balanceOf(address(this)));
    }

    function approve(IERC20 token, uint256 amount) public {
        require(msg.sender == owner, "only owner can approve");
        token.approve(vaultRelayer, amount);
    }

    function curvedOrderHash(CurvedOrder.Data calldata _curvedOrder) public pure returns (bytes32 _hash) {
        _hash = keccak256(abi.encode(_curvedOrder));
    }
}
