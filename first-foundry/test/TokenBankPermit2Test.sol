// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/tokenBankContract/tokenBankPermit2Contract.sol";
import "permit2/src/Permit2.sol";
import "../src/NFTmarket/ERC20.sol";

contract TokenBankTest is Test {
    TokenBank public tokenBank;
    Permit2 public permit2;
    BaseERC20 public token;

    address public user = vm.addr(1);
    uint256 public userPrivateKey = 1;

    function setUp() public {
        // 部署 ERC20 代币
        token = new BaseERC20();

        // 给用户铸造一些代币
        deal(address(token), user, 1000);

        // 部署 Permit2 合约
        permit2 = new Permit2();

        // 部署 TokenBank 合约
        tokenBank = new TokenBank(address(token), address(permit2));
    }

    function testDepositWithPermit2() public {
        uint256 amount = 100 * 1e18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;

        // 构造 PermitTransferFrom 结构
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(token),
                amount: amount
            }),
            nonce: nonce,
            deadline: deadline
        });

        // 构造 SignatureTransferDetails 结构
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: user,
            requestedAmount: amount
        });

        // 生成签名哈希
        bytes32 domainSeparator = permit2.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                permit2.PERMIT_TRANSFER_FROM_TYPEHASH(),
                permit.permitted.token,
                permit.permitted.amount,
                permit.nonce,
                permit.deadline,
                keccak256(abi.encode(
                    permit2.TRANSFER_DETAILS_TYPEHASH(),
                    transferDetails.to,
                    transferDetails.requestedAmount
                ))
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // 使用用户的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 调用 depositWithPermit2()
        vm.prank(user);
        tokenBank.depositWithPermit2(permit, transferDetails, signature);

        // 验证余额更新
        uint256 bankBalance = tokenBank.balanceOf(user);
        assertEq(bankBalance, amount);

        // 验证 TokenBank 合约持有的代币数量
        uint256 bankTokenBalance = token.balanceOf(address(tokenBank));
        assertEq(bankTokenBalance, amount);

        // 验证用户代币余额减少
        uint256 userTokenBalance = token.balanceOf(user);
        assertEq(userTokenBalance, 900 * 1e18);
    }
}