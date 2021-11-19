// pragma solidity ^0.4.25;
pragma solidity ^0.8.10;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    uint256 private numFundedAirlines;                              // To store count of funded airlines
    uint256 private numRegisteredAirlines;                          // To store count of registered airlines
    uint256 private constant MINIMUM_FUNDING_AMOUNT = 10 ether;

    struct Airline{
        uint256 airlineFunds;
        address[] registrationVotes;
        bool isRegistered;
        bool isFunded; //Once registered and fees paid, the airline will become active
    }
    mapping(address => Airline) private airlines;                       //To store all airline address to airline mapping

    struct Insurance{
        address airlineAddress;
        mapping(address => uint256) insuredPassengerPremiums;
        address[] insuredPassengers;
        bool isPaid;
    }
    mapping(bytes32 => Insurance) private insurances;                  //To store all flightKey to Insurance mapping


    mapping(address => uint256) passengerWallets;                      //To store insurance amounts to be given to insured passengers


    mapping(address => bool) private authorizedCallers;                 //To store authorized callers
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner{
        // require(mode != operational, 'Status already set to desired mode');
        operational = mode;
    }

    function numberOfFundedAirlines() external requireIsOperational returns(uint256){
        return numFundedAirlines;
    }

    
    function numberOfRegisteredAirlines() external requireIsOperational returns(uint256){
        return numRegisteredAirlines;
    }

    function isAirlineRegistered(address airline) external requireIsOperational returns(bool){
        return airlines[airline].isRegistered;
    }

    function isAirlineFunded(address airline) external requireIsOperational returns(bool){
        return airlines[airline].isFunded;
    }


    function getVotesForAirline(address airline) external requireIsOperational returns(uint256){
        return airlines[airline].registrationVotes.length;
    }

    function voteToRegisterAirline(address airline,address voter) external requireIsOperational{
        require(msg.sender!=airline, 'Airline cannot vote to register itself');

        bool callerHasAlreadyVoted = false;

        for(uint i=0; i<airlines[airline].registrationVotes.length; i++){
            if(airlines[airline].registrationVotes[i]==voter){
                callerHasAlreadyVoted = true;
                break;
            }
        }

        require(!callerHasAlreadyVoted, 'Caller has already voted to register this Airline');

        airlines[airline].registrationVotes.push(voter);
    }


    function authorizeCaller(address caller) external requireIsOperational requireContractOwner{
        authorizedCallers[caller] = true;
    }



    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline (address airline) external{
        airlines[airline].isRegistered = true;

        numRegisteredAirlines = numRegisteredAirlines.add(1);
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address payable passenger, bytes32 flightKey, address airlineAddress) external payable requireIsOperational{
        //Add the premium paid by the passenger to airline funds
        uint256 premiumAmount = msg.value;

        airlines[airlineAddress].airlineFunds = airlines[airlineAddress].airlineFunds.add(premiumAmount);

        
        insurances[flightKey].insuredPassengerPremiums[passenger] = insurances[flightKey].insuredPassengerPremiums[passenger].add(premiumAmount);

        insurances[flightKey].insuredPassengers.push(passenger);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airline, bytes32 flightKey)external  requireIsOperational{
        require(!insurances[flightKey].isPaid,'This insurance has been credited to insurees already');

        for(uint i=0; i<insurances[flightKey].insuredPassengers.length; i++){

            //Insurance Amount to be credited
            uint256 insuranceAmount= insurances[flightKey].insuredPassengerPremiums[insurances[flightKey].insuredPassengers[i]].mul(3).div(2);

            //First Debit
            airlines[airline].airlineFunds = airlines[airline].airlineFunds.sub(insuranceAmount);

            //Then Credit
            passengerWallets[insurances[flightKey].insuredPassengers[i]] = passengerWallets[insurances[flightKey].insuredPassengers[i]].add(insuranceAmount);
        }

        insurances[flightKey].isPaid = true;

    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay (address payable passenger) external requireIsOperational{
        require(passengerWallets[passenger] > 0 ,'Passenger does not have any funds in their walelt to withdraw');

        //First Debit
        uint256 amountToTransfer = passengerWallets[passenger];
        passengerWallets[passenger] = 0;

        //Then Credit
        passenger.transfer(amountToTransfer);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address airline) public payable requireIsOperational{

        uint fundingAmount = msg.value;
        airlines[airline].airlineFunds = airlines[airline].airlineFunds.add(fundingAmount);
        airlines[airline].isFunded = true;

        numFundedAirlines = numFundedAirlines.add(1);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
//    fallback() external payable {}

}

