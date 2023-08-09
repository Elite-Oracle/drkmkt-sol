import "compiler_test.sol";

contract ImportTest {
    CompilerTest ct;
    function ImportTest(){
        ct = new CompilerTest();
    }
}