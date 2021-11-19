import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    buyInsurance(flight, premiumAmount, callback) {
        let self = this;
        let payload = {
            passenger: self.passengers[0],
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .buyInsurance(payload.passenger,payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner,value:this.web3.utils.toWei(premiumAmount, "ether"), gas: 9999999}, (error, result) => {
                callback(error, payload);
            });
    }


    fund(airline, fundingAmount, callback) {
        let self = this;
        let payload = {
            airline: airline,
            fundingAmount:fundingAmount
        } 
        self.flightSuretyApp.methods
            .fund(payload.airline)
            .send({ from: self.owner,value:this.web3.utils.toWei(fundingAmount, "ether"), gas: 9999999}, (error, result) => {
                callback(error, payload);
            });
    }


    registerAirline(airline,callback) {
        let self = this;
        let payload = {
            airline: airline,
        } 
        self.flightSuretyApp.methods
            .registerAirline(payload.airline)
            .send({ from: self.owner, gas: 9999999}, (error, result) => {
                callback(error, payload);
            });
    }


}