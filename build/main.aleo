import credits.aleo;
program mining.aleo;

struct bond_state:
    validator as address;
    microcredits as u64;

struct unbond_state:
    microcredits as u64;
    height as u32;

struct PoolInfo:
    validator as address;
    is_open as boolean;

mapping admins:
    key as address.public;
    value as boolean.public;

mapping bonded:
    key as address.public;
    value as u64.public;

mapping unbonding:
    key as address.public;
    value as unbond_state.public;

mapping totals:
    key as u8.public;
    value as u64.public;

mapping pool_info:
    key as u8.public;
    value as PoolInfo.public;

function initialize:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/transfer_public_as_signer mining.aleo r1 into r2;
    call credits.aleo/bond_public r0 mining.aleo r1 into r3;
    async initialize self.caller r0 r1 r2 r3 into r4;
    output r4 as mining.aleo/initialize.future;

finalize initialize:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    input r3 as credits.aleo/transfer_public_as_signer.future;
    input r4 as credits.aleo/bond_public.future;
    await r3;
    await r4;
    set true into admins[r0];
    contains totals[0u8] into r5;
    not r5 into r6;
    assert.eq r6 true;
    set r2 into totals[0u8];
    set r2 into bonded[r0];
    cast r1 true into r7 as PoolInfo;
    set r7 into pool_info[0u8];

function set_pool_state:
    input r0 as boolean.public;
    async set_pool_state self.caller r0 into r1;
    output r1 as mining.aleo/set_pool_state.future;

finalize set_pool_state:
    input r0 as address.public;
    input r1 as boolean.public;
    get admins[r0] into r2;
    assert.eq r2 true;
    get pool_info[0u8] into r3;
    cast r3.validator r1 into r4 as PoolInfo;
    set r4 into pool_info[0u8];

function bond_public:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/transfer_public_as_signer mining.aleo r1 into r2;
    call credits.aleo/bond_public r0 mining.aleo r1 into r3;
    async bond_public self.caller r0 r1 r2 r3 into r4;
    output r4 as mining.aleo/bond_public.future;

finalize bond_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    input r3 as credits.aleo/transfer_public_as_signer.future;
    input r4 as credits.aleo/bond_public.future;
    await r3;
    await r4;
    get pool_info[0u8] into r5;
    assert.eq r5.validator r1;
    assert.eq r5.is_open true;
    get.or_use bonded[r0] 0u64 into r6;
    add r6 r2 into r7;
    set r7 into bonded[r0];
    get totals[0u8] into r8;
    add r8 r2 into r9;
    set r9 into totals[0u8];

function unbond_public:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/unbond_public mining.aleo r1 into r2;
    async unbond_public self.caller r0 r1 r2 into r3;
    output r3 as mining.aleo/unbond_public.future;

finalize unbond_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    input r3 as credits.aleo/unbond_public.future;
    cast mining.aleo 0u64 into r4 as bond_state;
    get.or_use credits.aleo/bonded[mining.aleo] r4 into r5;
    await r3;
    get.or_use admins[r0] false into r6;
    is.eq r0 r1 into r7;
    get bonded[r1] into r8;
    get totals[0u8] into r9;
    contains credits.aleo/bonded[mining.aleo] into r10;
    not r10 into r11;
    branch.eq r6 false to end_then_0_0;
    branch.eq r11 false to end_then_1_2;
    assert.eq r8 r9;
    branch.eq true true to end_otherwise_1_3;
    position end_then_1_2;
    position end_otherwise_1_3;
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    assert.eq r7 true;
    not r11 into r12;
    assert.eq r12 true;
    position end_otherwise_0_1;
    sub r8 r2 into r13;
    sub r9 r2 into r14;
    is.eq r13 0u64 into r15;
    or r15 r11 into r16;
    branch.eq r16 false to end_then_0_4;
    remove bonded[r1];
    branch.eq true true to end_otherwise_0_5;
    position end_then_0_4;
    set r13 into bonded[r1];
    position end_otherwise_0_5;
    is.eq r14 0u64 into r17;
    or r17 r11 into r18;
    branch.eq r18 false to end_then_0_6;
    remove totals[0u8];
    remove pool_info[0u8];
    branch.eq true true to end_otherwise_0_7;
    position end_then_0_6;
    set r14 into totals[0u8];
    position end_otherwise_0_7;
    add block.height 360u32 into r19;
    cast 0u64 r19 into r20 as unbond_state;
    get.or_use unbonding[r1] r20 into r21;
    ternary r11 r5.microcredits r2 into r22;
    add r21.microcredits r22 into r23;
    cast r23 r19 into r24 as unbond_state;
    set r24 into unbonding[r1];
    get.or_use totals[1u8] 0u64 into r25;
    add r25 r22 into r26;
    set r26 into totals[1u8];

function claim_unbond_public:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/transfer_public r0 r1 into r2;
    async claim_unbond_public r0 r1 r2 into r3;
    output r3 as mining.aleo/claim_unbond_public.future;

finalize claim_unbond_public:
    input r0 as address.public;
    input r1 as u64.public;
    input r2 as credits.aleo/transfer_public.future;
    await r2;
    get unbonding[r0] into r3;
    assert.eq r3.microcredits r1;
    gte block.height r3.height into r4;
    assert.eq r4 true;
    remove unbonding[r0];
    get totals[1u8] into r5;
    sub r5 r1 into r6;
    set r6 into totals[1u8];

function transfer_public:
    input r0 as address.public;
    input r1 as u64.public;
    call credits.aleo/transfer_public r0 r1 into r2;
    async transfer_public self.caller r0 r1 r2 into r3;
    output r3 as mining.aleo/transfer_public.future;

finalize transfer_public:
    input r0 as address.public;
    input r1 as address.public;
    input r2 as u64.public;
    input r3 as credits.aleo/transfer_public.future;
    await r3;
    get admins[r0] into r4;
    assert.eq r4 true;
    get credits.aleo/account[mining.aleo] into r5;
    cast mining.aleo 0u64 into r6 as bond_state;
    get.or_use credits.aleo/bonded[mining.aleo] r6 into r7;
    cast 0u64 0u32 into r8 as unbond_state;
    get.or_use credits.aleo/unbonding[mining.aleo] r8 into r9;
    add r5 r7.microcredits into r10;
    add r10 r9.microcredits into r11;
    get.or_use totals[0u8] 0u64 into r12;
    get.or_use totals[1u8] 0u64 into r13;
    add r12 r13 into r14;
    gte r11 r14 into r15;
    assert.eq r15 true;

function fallback_unbond_if_removed:
    input r0 as address.public;
    async fallback_unbond_if_removed r0 into r1;
    output r1 as mining.aleo/fallback_unbond_if_removed.future;

finalize fallback_unbond_if_removed:
    input r0 as address.public;
    contains credits.aleo/bonded[mining.aleo] into r1;
    not r1 into r2;
    assert.eq r2 true;
    get bonded[r0] into r3;
    get totals[0u8] into r4;
    remove bonded[r0];
    sub r4 r3 into r5;
    is.eq r5 0u64 into r6;
    branch.eq r6 false to end_then_0_8;
    remove totals[0u8];
    remove pool_info[0u8];
    branch.eq true true to end_otherwise_0_9;
    position end_then_0_8;
    set r5 into totals[0u8];
    position end_otherwise_0_9;
    add block.height 360u32 into r7;
    cast 0u64 r7 into r8 as unbond_state;
    get.or_use unbonding[r0] r8 into r9;
    add r9.microcredits r3 into r10;
    cast r10 r7 into r11 as unbond_state;
    set r11 into unbonding[r0];
    get.or_use totals[1u8] 0u64 into r12;
    add r12 r3 into r13;
    set r13 into totals[1u8];
