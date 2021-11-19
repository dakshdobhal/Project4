
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    //Fund the contract owner -- first airline
    await config.flightSuretyApp.fund(config.owner,{value:web3.utils.toWei("10", "ether")});

  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();


  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);
      
  });


  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
 
  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

    await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try 
    {
      //   await config.flightSurety.setTestingMode(true);
        await config.flightSuretyData.getNumRegisteredAirlines();

    }
    catch(e) {
        reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

    // Set it back for other tests to work
    // await config.flightSuretyData.setOperatingStatus(true);
    await config.flightSuretyData.setOperatingStatus(true);

  });

  // My tests

  it(`allows airline to be active only after funding is paid`, async function () {


    let reverted = false;
    let newAirline = accounts[2];
    try 
    {

        await config.flightSuretyApp.registerAirline(newAirline);

    }
    catch(e) {
        reverted = true;
        console.log("ERROR IN REGISTRATION");
    }
    let ans = await config.flightSuretyData.isAirlineFunded.call(newAirline);
    console.log(ans);

    let ans2 = await config.flightSuretyData.isAirlineRegistered.call(accounts[2]);
    console.log("accounts[2]  = ",ans2);


    assert.equal(ans, false, "isFunded set as true even for airlines that have not paid funding amount");      


  });

  it(`registers airlines before 4 airlines are registered but requires voting once the minimum number of registered airlines is reached`, async function () {


    try 
    {

      await config.flightSuretyApp.registerAirline(accounts[3]);
  
      await config.flightSuretyApp.registerAirline(accounts[4]);
  
      await config.flightSuretyApp.registerAirline(accounts[5]);
  
      await config.flightSuretyApp.registerAirline(accounts[6]);

      await config.flightSuretyApp.fund(accounts[2],{value:web3.utils.toWei("10", "ether")});
      await config.flightSuretyApp.registerAirline(accounts[6],{from:accounts[2]});


    }
    catch(e) {
        console.log("ERROR IN REGISTRATION",e);
    }

    let ans1 = await config.flightSuretyData.isAirlineRegistered.call(accounts[4]);
    let ans2 = await config.flightSuretyData.isAirlineRegistered.call(accounts[5]);
    let ans3 = await config.flightSuretyData.isAirlineRegistered.call(accounts[6]);
    

    assert.equal(ans1, true, "isRegistered set as false even for airlines that were registered before voting requirement was initiated");      
    assert.equal(ans2, false, "isRegistered set as true even for airlines that don't have majority of votes");      
    assert.equal(ans3, true, "isRegistered set as false even for airlines that have majority of votes");      


  });


  it(`Markes airline as isfunded only when minimum funding amount is paid`, async function () {


    try 
    {


      await config.flightSuretyApp.fund(accounts[3],{value:web3.utils.toWei("10", "ether")});
  
      await config.flightSuretyApp.fund(accounts[4],{value:web3.utils.toWei("3", "ether")});
  
    }
    catch(e) {
        console.log("ERROR IN FUNDING",e);
    }

    let ans1 = await config.flightSuretyData.isAirlineFunded.call(accounts[3]);
    let ans2 = await config.flightSuretyData.isAirlineFunded.call(accounts[4]);
    

    assert.equal(ans1, true, "isFunded set as false even for airlines that are funded");      
    assert.equal(ans2, false, "isRegistered set as true even for airlines that are not funded");      


  });


});
