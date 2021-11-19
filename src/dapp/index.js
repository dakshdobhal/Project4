
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })


        DOM.elid('buy-insurance').addEventListener('click', () => {
            let premiumAmount = DOM.elid('premium-amount').value;
            // Write transaction
            contract.buyInsurance(flight, premiumAmount, (error, result) => {
                display('Passenger', 'Insurace Bought', [ { label: 'Insurance Purchased', error: error, value: result.passenger + ' ' + result.flight} ]);
            });
        })

        DOM.elid('register-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline-address').value;
            // Write transaction
            contract.registerAirline(airline, (error, result) => {
                display('Airline', 'Airline Registered', [ { label: 'Airline Registered', error: error, value: result.airline} ]);
            });
        })
        
        DOM.elid('fund-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline-address').value;
            let fundingAmount = DOM.elid('funding-amount').value
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Airline', 'Airline Funded', [ { label: 'AirlineFunded', error: error, value: result.airline + ' funded ' + result.fundingAmount + ' ether'} ]);
            });
        })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







