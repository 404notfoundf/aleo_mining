// The 'test_mining' test program.
import mining_pool_online_v1_test.aleo;
program test_mining.aleo {

    @test
    script test_it() {
        let result: u64 = mining_pool_online_v1_test.aleo/initialize("aleo1z8yla4welcacd9qag0ztjcjzrm275a8xafqxrl9j7a0uefvgdyxs0nnhxm", 2u64);
        assert_eq(result, 3u32);
    }

    @test
    @should_fail
    transition do_nothing() {
        let result: u32 = mining.aleo/main(2u32, 3u32);
        assert_eq(result, 3u32);
    }
    
    @noupgrade
    async constructor() {}
}
