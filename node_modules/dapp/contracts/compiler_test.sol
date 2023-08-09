/// @title This is the contract title.
/// @author Peter Griffin
contract CompilerTest{

    address public owner;

    function CompilerTest(){
        owner = msg.sender;
    }

    /// @notice Set the owner address.
    /// @dev This should be the documentation of the function for the developer docs
    /// @param ownerIn The address of the new owner.
    function setOwner(address ownerIn){
        owner = ownerIn;
    }
}