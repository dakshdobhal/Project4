import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';




let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

let oracles = [];

async function initializeOracles() {

  let oracleAaccounts = await web3.eth.getAccounts().slice(11,33); //first 10 are used in the testing already, atleast 21 more are needed

  for (let i=0;i<oracleAaccounts.length;i++) {
    let oracleAccount = oracleAaccounts[i];

    try {
      await flightSuretyApp.methods.registerOracle().send({
        from: oracleAccount, value: web3.utils.toWei('1', 'ether')});
    } catch (e) {
      console.log('Error in oracle registration' + e);
    }

    oracles.push(oracleAccount) //persisted in memory

  }
}

initializeOracles();


//Respond whenever oracleRequest is emitted
//Source = https://betterprogramming.pub/ethereum-dapps-how-to-listen-for-events-c4fa1a67cf81
flightSuretyApp.events.OracleRequest({})
    .on('data', async function(event){
        console.log(event.returnValues);
        let index = event.returnValues.index;
        let airline = event.returnValues.airline;
        let flight = event.returnValues.flight;
        let timestamp = event.returnValues.timestamp;        

        //loop through all registered oracles
        for(let i=0;i<oracles.length;i++){
          let oracle = oracles[i];
          let oracleIndexes = await flightSuretyApp.methods.getMyIndexes.send({from:oracle});

          // identify those oracles for which the OracleRequest event applies
          if(index == oracleIndexes[0] || index == oracleIndexes[1] || index == oracleIndexes[2]){
              let statusCode = 10;
              await flightSuretyApp.methods.submitOracleResponse(index, airline,flight,timestamp,statusCode).send({from:oracle});
          }
        }

        // Do something here
    })
    .on('error', console.error);


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


