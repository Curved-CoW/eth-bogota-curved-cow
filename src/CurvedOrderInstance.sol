// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";
import "./interfaces/IERC20.sol";
import {GPv2EIP1271} from "./interfaces/ERC1271.sol";
import "./interfaces/ICoWSwapSettlement.sol";

contract CurvedOrderInstance is EIP1271Verifier {
    ICoWSwapSettlement public immutable settlement;
    address private constant vaultRelayer = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address public immutable owner;
    IERC20 public immutable sellToken;
    CurvedOrder.Data public curvedOrder;

    bytes32 public _curvedOrderHash;
    uint256 private constant ECDSA_SIGNATURE_LENGTH = 65;

    bytes32 private constant DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @dev The EIP-712 domain name used for computing the domain separator.
    bytes32 private constant DOMAIN_NAME = keccak256("Gnosis Protocol");

    /// @dev The EIP-712 domain version used for computing the domain separator.
    bytes32 private constant DOMAIN_VERSION = keccak256("v2");

    /// @dev Marker value indicating an order is pre-signed.
    uint256 private constant PRE_SIGNED = uint256(keccak256("GPv2Signing.Scheme.PreSign"));

    /// @dev The domain separator used for signing orders that gets mixed in
    /// making signatures for different domains incompatible. This domain
    /// separator is computed following the EIP-712 standard and has replay
    /// protection mixed in so that signed orders are only valid for specific
    /// GPv2 contracts.
    bytes32 public immutable domainSeparator;

    constructor(address owner_, IERC20 _sellToken, ICoWSwapSettlement _settlement) {
        owner = owner_;
        sellToken = _sellToken;
        settlement = _settlement;
        // _sellToken.approve(_settlement.vaultRelayer(), type(uint256).max);
        uint256 chainId;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }

        domainSeparator = keccak256(abi.encode(DOMAIN_TYPE_HASH, DOMAIN_NAME, DOMAIN_VERSION, chainId, address(this)));
    }


    function withDraw(IERC20 token) public {
      require(msg.sender == owner, "only owner can withdraw");
      token.transfer(owner, token.balanceOf(address(this)));
    }

    function approve(IERC20 token, uint amount) public {
      require(msg.sender == owner, "only owner can approve");
      token.approve(vaultRelayer, amount);
    }



    /// @param message The signed message.
    /// @param encodedSignature The encoded signature.
    function ecdsaRecover(bytes32 message, bytes calldata encodedSignature) public pure returns (address signer) {
        require(encodedSignature.length == ECDSA_SIGNATURE_LENGTH, "GPv2: malformed ecdsa signature");

        bytes32 r;
        bytes32 s;
        uint8 v;

        // NOTE: Use assembly to efficiently decode signature data.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // r = uint256(encodedSignature[0:32])
            r := calldataload(encodedSignature.offset)
            // s = uint256(encodedSignature[32:64])
            s := calldataload(add(encodedSignature.offset, 32))
            // v = uint8(encodedSignature[64])
            v := shr(248, calldataload(add(encodedSignature.offset, 64)))
        }

        signer = ecrecover(message, v, r, s);
        require(signer != address(0), "GPv2: invalid ecdsa signature");
    }

    function curvedOrderHash(CurvedOrder.Data calldata _curvedOrder) public returns (bytes32 _hash) {
        bytes32 _hash = keccak256(abi.encode(_curvedOrder));
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
}
