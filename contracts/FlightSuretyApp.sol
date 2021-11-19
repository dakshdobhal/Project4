// pragma solidity ^0.4.25;
pragma solidity ^0.8.10;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint8 private constant MINIMUM_AIRLINES_TO_START_VOTING = 4;
    uint256 private constant MINIMUM_FUNDING_AMOUNT = 10 ether;

    FlightSuretyData flightSuretyData;
    address payable flightSuretydataContractAddress;
    
    // Event fired each time an airline is registered
    event AirlineRegistered(address airline);

    // Event fired each time a flight is registered
    event FlightRegistered(string flight,address caller,uint256 updatedTimestamp);

    // Event fired each time an insurance is paid to insurees
    event InsureesCredited(address airline, bytes32 flightKey);

    // Event fired each time an insurance in bought
    event InsuranceBought(address caller, address payable passenger, address airline, uint256 premiumAmount);

    // Event fired each time an airline is funded
    event AirlineFunded(address caller, address airline, uint256 fundingAmount);

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
            bool isRegistered;
            uint8 statusCode;
            uint256 updatedTimestamp;        
            address airline;
    }
    mapping(bytes32 => Flight) private flights;

 
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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
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
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address flightSuretydataContractAddress) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(flightSuretydataContractAddress);

        //Directly register the first airline with contract address 
        flightSuretyData.registerAirline(contractOwner); 
        
        emit AirlineRegistered(contractOwner);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            returns(bool) 
    {
        return  flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address airline) external requireIsOperational returns(bool success, uint256 votes){
        // require(!flightSuretyData.isAirlineRegistered(airline),'This airline is already registered');
        if(flightSuretyData.isAirlineRegistered(airline)){
            return (true,0);
        }

        // contractOwner is exempt from the funding requirement
        // require((msg.sender==contractOwner||flightSuretyData.isAirlineFunded(msg.sender)),'Airline must be funded to register another airline');
        require(flightSuretyData.isAirlineFunded(msg.sender),'Airline must be funded to register another airline');

        // Directly Register Airline in this case without voting
        if(flightSuretyData.numberOfRegisteredAirlines() < MINIMUM_AIRLINES_TO_START_VOTING){
            flightSuretyData.registerAirline(airline);
            emit AirlineRegistered(airline);
            return(true,0);
        }

        // Else voting is required -- basically airline has to have >= (numberOfFundedAirlines)/2
        // votes by funded airlines. 
        require(flightSuretyData.isAirlineRegistered(msg.sender) ,'Arline must be registered to participate in voting');

        flightSuretyData.voteToRegisterAirline(airline,msg.sender);
        uint256 votesReceived = flightSuretyData.getVotesForAirline(airline);

        if(votesReceived >= flightSuretyData.numberOfRegisteredAirlines().div(2)){
            flightSuretyData.registerAirline(airline);
            emit AirlineRegistered(airline);
            return(true,votesReceived);
        }

        return (false, votesReceived);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(address airline, string memory flight, uint256 updatedTimestamp) external requireIsOperational{
        bytes32 flightKey = getFlightKey(airline, flight, updatedTimestamp);


        require(!flights[flightKey].isRegistered, 'Flight is already registered');
        require(flightSuretyData.isAirlineFunded(msg.sender),'Only funded airlines can register flights');


        flights[flightKey].isRegistered = true;
        flights[flightKey].statusCode = STATUS_CODE_UNKNOWN;
        flights[flightKey].updatedTimestamp = updatedTimestamp;
        flights[flightKey].airline = msg.sender;

        emit FlightRegistered(flight,msg.sender,updatedTimestamp);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus (address airline,string memory flight, uint256 timestamp,uint8 statusCode) internal requireIsOperational{
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(flights[flightKey].isRegistered,'This flight is not registered');

        if(statusCode == STATUS_CODE_LATE_AIRLINE){
            flightSuretyData.creditInsurees(airline,flightKey);
            emit InsureesCredited(airline,flightKey);
        }

    }


    function buyInsurance(address payable passenger,address airline,string memory flight,uint256 timestamp) external payable requireIsOperational{
        require(flightSuretyData.isAirlineFunded(airline),'Insurance can be purchased from funded airlines only');
        require(msg.value<=1 ether,'Insurance premium amount can be at most 1 ether');

        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        // flightSuretydataContractAddress.transfer(msg.value);
        flightSuretyData.buy{value:msg.value}(passenger, flightKey, airline);

        emit InsuranceBought(msg.sender,passenger, airline, msg.value);
    }

    function fund(address airline) external payable requireIsOperational{
        require(flightSuretyData.isAirlineRegistered(airline) , 'Airline must be registered before it can pay the funding amount and become active');
        require(msg.value >= MINIMUM_FUNDING_AMOUNT , 'Fundding is less than the Minimum funding amount ') ;

        // flightSuretydataContractAddress.transfer(msg.value);
        flightSuretyData.fund{value:msg.value}(airline);

        emit AirlineFunded(msg.sender, airline, msg.value);

    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline,string memory flight,uint256 timestamp) external{
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));

        // Usuario storage newUsuario = circulo[id];
        // numUsuarios++;
        // newUsuario.id = id;
        // newUsuario.debe[idDebe] = valDebe;
        // newUsuario.leDebe[idLeDebe] = valLedebe;


        //Source = https://stackoverflow.com/questions/64200059/solidity-problem-creating-a-struct-containing-mappings-inside-a-mapping
        ResponseInfo storage newResponseInfo = oracleResponses[key];
        newResponseInfo.requester = msg.sender;
        newResponseInfo.isOpen = true;

        // oracleResponses[key] = ResponseInfo({
        //                                         requester: msg.sender,
        //                                         isOpen: true
        //                                     });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string memory flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
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

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
