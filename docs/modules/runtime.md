# ProofForge.Svm.Runtime

## Purpose

普通 Lean 名，抽出后变成 syscall / AccountInfo 读。不是新 DSL。

合约 `open ProofForge.Svm.Runtime`（或经 `@[pf_inline]` 消去的 SDK 名字）。抽出器只识别具名 Runtime stub。根层不再提供混合 façade。

协议入口和持久容器分两层：`Svm.EntryAdapter` 负责 target-owned wire decode、physical
account contract 与 raw/generated dispatch；`Svm.AccountStorage` 负责 fixed-capacity
account-resident map/queue/allocator/tree routine。两层通过 `Svm.Component.Query/Call` 的稳定
lowering bridge 进入普通 CFG；generic Ops、IR 与主 Emit 只认识一个 `.component` case。
Queue、Map、Allocator 与 audit recorder 组合固定 Region/Field/index、有界循环、checked
load/store、bounded scratch 与 CPI sink；新增组件只扩 component-owned vocabulary/backend，
不为每个 Phoenix/Map/queue 功能横向增加顶层 Ops、IR 与主 Emit case。

## Surface

- `clockSlot : UInt64` — 链上 `sol_get_clock_sysvar` → `Clock.slot`（物理 slot）。宿主 `@[irreducible]` stub，值是 0，不要 unfold。
- `clockEpoch : UInt64` — 同一条 syscall → `Clock.epoch`（偏移 16）。宿主 stub。
- `unixTime : UInt64` — 同一条 syscall → `Clock.unix_timestamp`@32，按无符号 u64。
- `slotsPerEpoch : UInt64` — 链上 `sol_get_epoch_schedule_sysvar` → 首 u64。宿主 stub。
- `rentExemption n` — 链上 `sol_get_rent_sysvar` → `lamports_per_byte * (128 + n)`。`n` 抽出时必须是常量。宿主 stub。
- `signerKey0 : UInt64` — 链上 `ACC0_KEY+0` 第一个小端 u64。用到该叶子的入口检查 `is_signer`。不是 `tx.origin`。
- `systemTransfer lamports` — 封闭 `system.transfer`。三账户 payer/recipient/System，`sol_invoke_signed_c`，无 signer seeds。

`unixTime` 已支持。32B key / owner 可通过四个 `UInt64` word 读取；把它们当作一个
native 32-byte value、以及运行时动态拼装 CPI 仍 fail closed。
- `invoke programIx metas data` — 编译期钉死的 CPI。抽出认这个名字。
- `CpiMeta.expectedDataLen` — 可选的精确账户 data 长度；目标发射器在 CPI 前检查，错长以
  `Custom(1)` 退出。未设置时不改变既有 recipe / digest。
- `invokeSigned programIx metas data seed bump` — 同一条发射器，一组 signer seeds。
- `invokeSignedSeeds programIx metas data seeds bump` — 一组编译期定形的异构 signer seeds；支持 ASCII、state key 和静态 account key，运行时只提供 bump。
- `batchRecorderBegin` / `batchRecorderAppend` / `batchRecorderFinish` — 不可约 source stubs；
  static sink/header/count geometry 与 `Array CpiWord` 抽成 `Svm.Component.Call.batchRecorder`。
  buffer 只在 invocation-local SDK 32 KiB bump heap 中；append 在 record/byte bound 前 flush，
  finish 必发（允许 header-only），不返回或持久化 pointer。
- `fifoCancelBegin` / `fifoCancelSide` / `fifoCancelUpToSide` / `fifoCancelFinish` 及三个
  aggregate query — 不可约 source stubs；抽成 `Svm.Component.Call/Query.fifoCancel`。组件自己
  组合 static one-based FIFO map、owner/size/trader balance fields、checked collateral、key
  cursor 与 recorder，按 fixed capacity 从 root 反复找 strict successor；跨 automatic
  recorder flush 只保留 scalar event index 与 released-lot totals。`fifoCancelUpToSide` 另外以
  capacity/search/cancel 三重 bound 遍历：每个 cursor result 在 owner/price filter 前计入
  search，只有 selected order 计入 cancel；bid/ask tick 均 inclusive，equal-price FIFO 不变，
  可静态选择逐单 claim 或保留
  free funds。完整 tree/free-list validator 必须在 source 中先行并由 IR guard 钉住；source
  不能直接选择内部 validated-remove backend。
- `PdaSeed.accData account offset length` — 直接引用 external account data 的编译期固定
  byte slice；`1 ≤ length ≤ 32`，形成 descriptor 前检查 `data_len ≥ offset+length`。seed
  指向本次 invocation 的 serialized account buffer，不复制、不分配，也不能持久化 pointer。
- 首个 CPI word `.selfEntry tag seed` — 声明唯一 raw self-entry；只接受 canonical seed PDA 的 readonly signer，认证后把完整 payload 作为一个 `sol_log_data` field 发布。
- `@[pf_svm_raw tag accountCount programAccount]` — 声明 target-owned packed 外部入口；tag
  是首个 u8，后续参数按 source 的 u8/u16/u32/u64 width 精确小端解码。adapter 静态消费
  account prefix，要求指定 physical account executable 且 key 等于当前 program id，然后把
  参数零扩展到普通 scalar locals。raw method 不得访问 managed `State`；协议持久数据必须走
  explicit `AccountStorage`。该 annotation 不产生 Op，raw instruction 不进入 generated IDL。
- `@[pf_svm_raw_borsh_options tag accountCount programAccount prefixParamCount [option widths]]`
  — 声明 bounded variable-length raw 入口。前 `prefixParamCount` 个 scalar 保持 packed little-
  endian；每个后续 Borsh `Option<T>` 在 source 参数中表示为 `(presence : UInt8, value : T)`，
  width 由 annotation 静态给出。entry adapter 只接受 discriminant 0/1，在读取 `Some` payload
  前检查动态 cursor end-bound，并要求最终 exact consumption；`None` 的 presence/value locals
  均规范化为零。route 只覆盖静态可证的 `[minDataLen, maxDataLen]`，不分配 heap buffer，
  不产生 generic codec Op，也不把 raw instruction 暴露进 generated IDL。
- `let _ := invoke...` — 被忽略的 CPI 结果按效应顺序保留；无论普通或 signed、单条或多条，后续 state writes 都不能被抽取器吞掉。
- lexical `let` 捕获的账户 read 在后续 account write/CPI 前 materialize；写前 snapshot
  不会因 substitution 在写后重读，源码明确放在写后的 read 则观察新值。
- init 中的静态 CPI 在账户初始化写回前执行；非 CPI init effect fail closed，不再静默省略。
- `systemTransfer` / `invokeAcc1` / `systemCreate` / `createPda` / `systemAssign` / `systemAllocate` / `systemAllocateWithSeed` / `systemCreateWithSeed` / `systemAssignWithSeed` / `systemTransferWithSeed` / `systemAdvanceNonce` / `tokenInitMint` / `tokenSyncNative` / `tokenTransferChecked` / `token2022TransferChecked` / `token2022TransferCheckedImmutable` / `token2022TransferCheckedNonTransferable` / `token2022TransferCheckedTransferFee` / `token2022SetAccountAuthorityImmutable` / `tokenTransferCheckedIx` / `tokenTransferCheckedSignedIx` / `tokenTransferSignedIx` / `tokenTransferCheckedMs2` / `tokenApproveCheckedMs2` / `tokenMintToChecked` / `tokenBurnChecked` / `tokenMintTo` / `tokenBurn` / `tokenInitAccount` / `tokenInitAccount2` / `tokenCloseAccount` / `tokenApproveChecked` / `tokenApprove` / `tokenFreezeAccount` / `tokenThawAccount` / `tokenSetMintAuthority` / `tokenSetAccountAuthority` / `tokenRevoke` / `tokenInitMultisig` / `tokenAccountSize` / `memoWrite` — 普通 Lean 包装，按 Runtime 命名空间统一展开成同一组 `invoke` / `invokeSigned` / `invokeSignedSeeds` 原语，不维护 recipe 名白名单。Token-2022 包装只接收 82B mint / 165B token account。
- 四个旧 `system*WithSeed` Runtime 名称保留 `"vault"` compatibility 输入；新应用使用
  `Svm.Sdk.System.AsciiSeed`，由 SDK 自动编码静态 ASCII seed 长度，并由 target verifier
  检查 1–32 bytes 与 bincode length 一致性。
- 旧 `memoWrite` Runtime 名称保留固定 `"ok"` compatibility 输入；新应用使用
  `Svm.Sdk.Memo.Ascii.write payload`。payload 是 ≤512-byte compile-time seven-bit ASCII，
  只在 exact Memo CPI geometry 上由 target verifier 约束；不是 runtime String/Vec，也不进入
  account state。runtime-selected/UTF-8 payload 继续 fail closed。
- ATA 不再有 Runtime policy wrapper。`Svm.Sdk.AssociatedToken` 的 role-typed
  Create/CreateIdempotent/RecoverNested plan 直接组合 generic `invoke`；selected Token/ATA
  program、账户次序和权限都是 compiler-erased static geometry，不增加 ATA Op/Emit recipe。
- `accLamports0` / `accOwner0` / `accDataLen0` / `accN` — 账户 0 只读 header。
- `isSigner0` / `isWritable0` / `isExecutable0` — 账户 0 旗，0 或 1；不强制入口签名。
- `accLamports1` / `accOwner1` / `accDataLen1` / `isSigner1` / `isWritable1` / `isExecutable1` — 账户 1 只读 header。读到这些叶子就 walk，不强制 acc0 signer。
- `findPda seed` — 当前 program id + 一条 ASCII 种子；链上 `sol_try_find_program_address`，返回 bump。
- `findPdaSeeds seeds` — 当前 program id + 编译期定形的异构 seed 列表；返回 canonical bump。
- `checkPdaSeeds account seeds` — 推导 canonical PDA 并比较目标账户完整 32-byte key；相等
  0，否则 1。`account` 与 CPI meta / `PdaSeed.accKey` 一样按 external-account region 编号；
  raw adapter 声明的 physical program prefix 不计入该编号，因此 tag 5 的 external `0` 是
  physical log account `1`。
- `sha256Lit seed` — 编译期 ASCII 字面量；链上 `sol_sha256`，返回 digest 第一个小端 u64。完整 32B / 多切片 / blake3 fail closed。
- `keccak256Lit seed` — 同形；链上 `sol_keccak256`（Ethereum Keccak，不是 FIPS SHA3-256）。blake3 / poseidon 仍 FC。
- `accKeyWord acc word` / `accOwnerWord acc word` — 账户 `acc < IR.maxTxAccountLocks` 的 32B key / owner 第 `word`∈{0..=3} 个小端 u64。抽出时必须是常量。`acc≥1` 走 walk，不强制入口签名。不是 `signerKey0`。
- `accDataWord acc word` — 账户 data 第 `word` 个小端 u64；账户和 word 均为编译期常量。发射器在形成 data pointer 前检查 `data_len ≥ 8*(word+1)`，短账户 `Custom(1)`。
- `accDataWordAt acc base stride capacity index` — `acc/base/stride/capacity` 编译期固定，零基 `index` 可运行时选择；发射器先检查 `index < capacity`，再检查计算出的 word 位于 `data_len` 内。只做账户内 zero-copy u64 读取，不分配或复制动态数组。
- `accDataWordSetAt acc base stride capacity index value` — 同一固定形状的账户内 u64
  写入 effect；只接受外部账户，要求 writable 且 owner 等于当前 program，并在 store 前
  检查账户数、`index < capacity` 和最终 `data_len`。连续 ignored writes 保持源码顺序；
  guarded `Except` success branch 也保留完整 effect sequence，不会被最终 state projection
  消除。失败以 `Custom(1)` 退出并由 SVM 回滚整条 instruction。它不返回或持久化
  pointer，也不把 transient heap 当账户 allocator。
- 该写入在 target 内部通过 `Svm.Component.Call.accountStorage` lowering：底层
  `Svm.AccountStorage.Call` 的 `Region/Field` 固定
  account/base/stride/capacity，显式记录 zero/one-based indexing，并统一提供 value
  traversal、geometry validation、canonical digest 与 read/write effect。主 SVM IR/emitter
  只看一个 generic component bridge；allocator/tree/map/queue 的 bounded routine 应继续
  进入 component-owned backend，而不是增加新的顶层 store emitter。它是 account-resident
  zero-copy backend，不是 Rust transient heap 或普通 `HashMap`。
- `accDataParentPathValid acc linksBase parentBase stride capacity maxDepth index root bump` —
  static shape + 最多 64 步的账户内 parent walk；运行时 index/root/bump 先过 1-based
  envelope，每步验证 color、parent 和 parent→child reciprocity，root 外 cycle 到界返回 0。
  只用常量 memory；不是 whole-tree 或 free-list membership proof。target 内部表示为
  `AccountStorage.Query.parentPathValid`：query 自己携带 static fields、arity、read effects、
  geometry 与 canonicalization，主 value emitter 只做 generic query dispatch。
- `accLamports` / `accDataLen` / `isSigner` / `isWritable` / `isExecutable` `acc` — 账户 `acc < IR.maxTxAccountLocks`（官方当前 64）header。旧名 `accLamports0` 等仍独立。
- `signerKey acc` — 该账户 key 首 u64；入口强制该账户 `is_signer`。旧名 `signerKey0` 仍独立。
- `ownerIsSelf acc` — owner 32B 是否等于当前 program id；相等 0 / 不等 1。
- `checkPda seed bump` — 旧的一条 ASCII 种子接口；链上只检查 bump 能否导出合法 PDA，成功 0 / 失败 1，不接收也不比较目标账户。需要完整 32B account-key 相等时使用 `checkPdaSeeds`。
- `cpiReturn` — 最近一次 CPI 的 8 字节返回；`sol_get_return_data`。长度不是 8 → Custom(1)。
- `cpiReturnLen` — 最近一次 CPI 返回数据的实际总长度（字节）；未设置时为 0。
- `cpiReturnProgramIdWord word` — 最近一次 CPI 返回数据设置者 program id 的第 `word`（编译期字面量 0..3）个 u64；无返回数据 → Custom(1)。宽于 8 字节的 payload 窗口当前剖面 fail closed。
- `tokenAccountSize` — Token GetAccountDataSize；返回值走 `cpiReturn`。
- `sha256Lit seed` / `keccak256Lit seed` — 编译期 ASCII 字面量 digest 首 u64。
- `sha256LitWord seed word` / `keccak256LitWord seed word` — 字面量 digest 的第 `word`（0..3）个 u64，凑齐完整 32B。
- `sha256DataWord acc off len word` / `keccak256DataWord acc off len word` — 账户 `acc` 数据区 `[off, off+len)` 的单切片 digest 第 `word` 个 u64；`len ≤ 1024`，越界读 → Custom(1)。多切片拼接、运行时拼缓冲、blake3/sha512/poseidon/secp256k1 本剖面 fail closed。

把完整 32B key 当作单一值、运行时拼的 CPI（动态 program id / remaining accounts）
fail closed。常量 `acc < 64` 的账户 header 和四个 key / owner word 已开；编译期钉死的
`invoke`、`unixTime` 和 `Bool` 字段也已开。


## Tests

`Examples/Svm/Clock.lean` + `runtime-tests/solana/tests/clock.rs`：两次 `warp_to_slot` 读 slot / epoch、`stamp` 写回、`key0` 缺 signer → `Custom(1)`。
`Examples/Svm/Info.lean` + `runtime-tests/solana/tests/info.rs`：余额 / owner 首 u64 / data_len / NUM_ACCOUNTS / 三旗；只读不改账户数据。
`Examples/Svm/Peer.lean` + `runtime-tests/solana/tests/peer.rs`：账户 1 的 lamports / owner 首 u64 / data_len / 三旗；缺第二账户 → `Custom(1)`。
`Examples/Svm/Hash.lean` + `runtime-tests/solana/tests/hash.rs`：`sha256Lit "vault"` / `"ok"` / `""` 的首 u64 与宿主 `sha2` 一致。
`Examples/Svm/HashWords.lean` + `runtime-tests/solana/tests/hash_words.rs`：`sha256LitWord` / `keccak256LitWord "vault"` 四字全部与宿主 sha2/sha3 一致。
`Examples/Svm/HashDataSha.lean` / `HashDataKeccak.lean` + `runtime-tests/solana/tests/hash_data.rs`：账户数据 `[0,32)` 与 `[4,36)` 单切片 digest 与宿主一致；短账户越界读 → `Custom(1)`。
`Examples/Svm/Keccak.lean` + `runtime-tests/solana/tests/keccak.rs`：`keccak256Lit "vault"` / `"ok"` / `""` 的首 u64 与宿主 `sha3::Keccak256` 一致。
`Examples/Svm/Keys.lean` + `runtime-tests/solana/tests/keys.rs`：账户 0/1 的 key / owner 按字读与宿主 `Pubkey` 一致；读 key 字不强制 signer；缺第二账户 → `Custom(1)`。
`Examples/Svm/Trio.lean` + `runtime-tests/solana/tests/trio.rs`：账户 2 header / key 字；`signerKey 1` 缺签名 Custom(1)；`ownerIsSelf 0` = 0、异 owner = 1。
`Examples/Svm/Gate.lean` + `runtime-tests/solana/tests/gate.rs`：Bool 字段 1 字节；`unixTime` 跟 `clock.unix_timestamp`。
`Examples/Svm/Nonce.lean` + `runtime-tests/solana/tests/nonce.rs`：AdvanceNonceAccount 缺 signer → `Custom(1)`。
`Examples/Svm/TokenOwner.lean` + `runtime-tests/solana/tests/token_owner.rs`：SetAuthority AccountOwner 改 owner；Approve 写 delegate。
`Examples/Svm/TokenMs.lean` + `runtime-tests/solana/tests/token_ms.rs`：InitializeMultisig2 m=2 n=2；未使用的 payer 不要求 signer。
`Examples/Svm/Pda.lean` + `runtime-tests/solana/tests/pda.rs`：`findPda "vault"` 的 bump 与宿主 `find_program_address` 一致；`checkPda` 对 canonical bump 返回 0，对 bump 0 返回 1。
`Examples/Svm/Signed.lean` + `runtime-tests/solana/tests/signed.rs`：canonical bump 签字成功；bump 0 失败。
`Examples/Svm/SysAlloc.lean` + `runtime-tests/solana/tests/sys_alloc.rs`：allocate 把空 System 账户扩到 16 字节；assign 把 owner 改成当前 program；缺 signer → `Custom(1)`。
`Examples/Svm/TokenMultisig.lean` + `runtime-tests/solana/tests/token_multisig.rs`：m=2 multisig authority 的 TransferChecked 精确转账与 ApproveChecked 写 delegate；缺一个 signer → `Custom(1)`。
`Examples/Svm/TokenMintBurn.lean` + `runtime-tests/solana/tests/token_mint_burn.rs`：MintTo/Burn 精确增减 amount 与 supply；InitializeAccount2 带 rent sysvar 初始化 owner。
`Examples/Svm/TokenAcc.lean` + `runtime-tests/solana/tests/token_acc.rs`：InitializeAccount3 写 owner/mint 且不要求 owner signer；CloseAccount 把 0 余额账户 lamports 退回 dest，并要求 owner signer。
`Examples/Svm/Memo.lean` + `runtime-tests/solana/tests/memo.rs`：经 bounded static Memo SDK CPI 进官方 Memo v3，应用选择字面量 `"ok"`；缺 signer → `Custom(1)`。
`Examples/Svm/CreatePda.lean` + `runtime-tests/solana/tests/create_pda.rs`：给 `"vault"` PDA 开 16 字节；bump 0 失败。
`Examples/Svm/TokenApprove.lean` + `runtime-tests/solana/tests/token_approve.rs`：ApproveChecked 写 delegate + delegated_amount；缺 signer → `Custom(1)`。
`Examples/Svm/TokenFreeze.lean` + `runtime-tests/solana/tests/token_freeze.rs`：Freeze 把 state 写成 Frozen；Thaw 写回 Initialized；缺 signer → `Custom(1)`。
`Examples/Svm/TokenAuth.lean` + `runtime-tests/solana/tests/token_auth.rs`：SetAuthority 把 mint_authority 改成 acc2；Revoke 清掉 delegate；缺 signer → `Custom(1)`。
`Examples/Svm/Epoch.lean` + `runtime-tests/solana/tests/epoch.rs`：默认 `slots_per_epoch` 432000；改 schedule 后再读一次。
`Examples/Svm/TokenSize.lean` + `runtime-tests/solana/tests/token_size.rs`：GetAccountDataSize 返回 165；未使用的 dummy 不要求 signer。
`Examples/Svm/TokenSizeVerified.lean` + `runtime-tests/solana/tests/token_size_verified.rs`：GetAccountDataSize 返回 165，且 `Sdk.ReturnData.setterIs` 校验返回数据设置者恰为 classic Token；token-2022 作 callee → `Custom(1)`。
`Examples/Svm/Token2022SizeVerified.lean` + `runtime-tests/solana/tests/token_2022_size_verified.rs`：`ReturnData.len == 8` 且设置者恰为 Token-2022；classic Token 作 callee → `Custom(1)`。
`Examples/Svm/SysSeed.lean` + `runtime-tests/solana/tests/sys_seed.rs`：AllocateWithSeed 开 16 字节；CreateAccountWithSeed 转 lamports；AssignWithSeed 改 owner；缺 signer → `Custom(1)`。
`Examples/Svm/SysXfer.lean` + `runtime-tests/solana/tests/sys_xfer.rs`：TransferWithSeed 从 `create_with_seed(acc0, "vault", program)` 转 lamports；缺 signer → `Custom(1)`。
`Examples/Svm/TokenMint2.lean` + `runtime-tests/solana/tests/token_mint2.rs`：InitializeMint2 写 decimals=6、authority=acc0；authority 不要求 signer。
`Examples/Svm/TokenNative.lean` + `runtime-tests/solana/tests/token_native.rs`：SyncNative 把 native 账户 amount 同步成多余 lamports；owner 不要求 signer。
`Examples/Svm/Token2022CpiGuard.lean` + `runtime-tests/solana/tests/token_2022_cpi_guard.rs`：source 带 CpiGuard 扩展的 TransferChecked；未锁成功，锁定的 owner 签名 CPI 转账被 token-2022 拒绝（CpiGuardTransferBlocked = Custom 42）；准入策略字节级校验 CpiGuard(11, 1B)。
`Examples/Svm/Token2022Pause.lean` + `runtime-tests/solana/tests/token_2022_pause.rs`：pausable mint 上 TransferChecked；未暂停成功，暂停时被 token-2022 拒绝（MintPaused = Custom 67）；准入策略字节级校验 Pausable(26, 33B)。
`Examples/Svm/HaltLog.lean` + `runtime-tests/solana/tests/halt_log.rs`：`sol_log_` 输出编译期 UTF-8 行（ELF `.rodata` 池，无运行时指针）；`sol_panic_`/`abort` 以官方 ABI（file/len/line/column=0）原子 halt，宿主侧分别为 `ProgramFailedToComplete`/`Abort` 终端。
`Examples/Svm/Token2022Tfee.lean` + `runtime-tests/solana/tests/token_2022_tfee.rs`：transfer-fee mint 上 TransferChecked；费用按 `ceil(amount·bps/1e4)` 封顶收取（1%、cap 5000 时 1M → 5k；40k → 400），source/dest 必须带 `TransferFeeAmount` 扩展；clock epoch 推进后用 newer schedule；缺 signer → `Custom(1)`。
`Examples/Svm/Token2022Ext.lean` + `runtime-tests/solana/tests/token_2022_ext.rs`：ImmutableOwner 账户的普通 TransferChecked 成功；NonTransferable mint/account 转账被 token-2022 拒绝（Custom 37）；ImmutableOwner 的 SetAuthority(AccountOwner) 被拒绝（Custom 34）。
`Examples/Svm/Token2022.lean` + `runtime-tests/solana/tests/token_2022.rs`：Token-2022 base-layout TransferChecked 精确转账；缺 signer、transfer-fee mint、enabled transfer-hook mint 均原子失败。
`Examples/Svm/Nested.lean` + `runtime-tests/solana/tests/nested.rs`：嵌套 projection 更新只写目标叶。
`Examples/Svm/Book.lean` + `runtime-tests/solana/tests/book.rs`：有界循环与运行时 Vector 下标写在链上执行。
`Examples/Lang.lean` + `runtime-tests/solana/tests/lang.rs`：位运算、mod-64 移位及 state-carrying fold 的链上语义。
`Examples/Svm/Tree.lean` + `runtime-tests/solana/tests/tree.rs`：红黑树插入布局，以及 black-leaf 删除 fixup、free-list 回收和精确地址复用。
`Examples/Svm/Seat.lean` + `runtime-tests/solana/tests/seat.rs`：PDA bump view、canonical seat PDA 创建、base/quote Token vault 初始化，以及 signer/writable 原子失败。
`Examples/Svm/SelfLog.lean` + `runtime-tests/solana/tests/self_log.rs`：当前 program id 的 signed self-CPI，canonical `"log"` PDA raw 入口、packed Borsh integer words、续段状态写回，以及 signer/writable/tag/key 失败矩阵。
`Examples/Svm/RawEntry.lean` + `runtime-tests/solana/tests/raw_entry.rs`：同一 ELF 的 generated/raw
dispatch；`07 || u8 || u64` exact decode、bounded trailing account、program account authentication，
以及 wrong tag/length、missing signer、wrong/non-executable program fail-closed matrix。
`Examples/Svm/Phoenix.lean` + `runtime-tests/solana/tests/phoenix.rs`：认证状态账户上的 ask/bid 生命周期、双向撮合、费用/seat 结算、classic SPL Token 双 vault deposit/withdraw、未注册 take-only 双 Token 腿、严格 slot/time TIF、三种 self-trade、官方形状的 authenticated AuditLogHeader/event self-CPI，以及 vault/mint/Token program/self program/log PDA/writable/signer/owner 原子失败；跨四档逐样本 refinement 仍由 host/IR 门覆盖。
`Examples/Svm/PhoenixV1Profile.lean` + `runtime-tests/solana/tests/phoenix_v1_profile.rs`：Phoenix canonical owner/discriminant、12 个 capacity tuple/exact length、固定 scalar/allocator header，以及编译期固定 geometry 的完整 bid/ask/trader tree/free-list partition；通用 `AccountStorage` 提供 bounded Key4/FIFO find、one-based field read/write、Sokoban insertion/removal/deposit，以及只保留 scalar key、删除后从 root 重查 strict upper-bound 的 ordered FIFO cursor，持久状态不使用 heap Map/Vec 或账户外 pointer。官方 raw tags 4–9 再组合 `EntryAdapter + Component`：tag 4/5 共享 exact 26-byte reduce wire；tag 6/7 是 exact one-byte no-payload CancelAll wire，在 complete validator 后由 `FifoCancel` 按 bids→asks、各侧 FIFO、owner-filter 顺序原位取消；tag 8/9 是 5..21-byte `side + Option<tick/search/cancel>` CancelUpTo wire，search-before-filter、side-inclusive tick、cancel cap 与 equal-price FIFO 都在同一 bounded component 中。tag 5/7/9 保留 free funds且无 Token CPI；tag 4/6 验证 9-account classic Token context，tag 6 只 claim 本次 aggregate release 并按 quote→base 提款；tag 8 逐单 claim 后只提款 selected side aggregate，保留 pre-existing free。audit header 使用 pre-increment sequence，global u16 event index 跨 32-record flush 不重置；missing trader/empty/no-match/zero-limit 发 exact 93-byte header-only batch。malformed tree/Borsh/token context 在 sequence/store/CPI 前原子失败。最小 profile 84,944 B；短 header `Custom(1)`。
