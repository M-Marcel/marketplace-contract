import React, { Component, Fragment, useState } from "react";
import {ethers} from 'ethers';
import abi from '../artifacts/contracts/Greeter.sol/Greeter.json';
const greetingAddress = "0x133e10f59919Ea1a228e840158B6adC4A0F72691";
const {ethereum} = window;
class MainGreeting extends Component {
    constructor(props) {
        super(props);
        this.state ={
            greeting:'',
            loading:'',
        }
        this.handleChange = this.handleChange.bind(this);
    }
fetchGreeting = async() =>{
    if(ethereum !== 'undefined')
    {
        const provider = new ethers.providers.Web3Provider(ethereum);
        
        const contract = new ethers.Contract(greetingAddress,abi.abi,provider);
        try{
        const data =  await contract.greet();
        this.setState({ loading:'We are fetching your wish message, please wait....'})
        this.setState({ loading:'You sent: '+data })
        }
        catch(err){
        console.log(err)
        }
    }
    }
 setGreeting = async() =>{
        const ETHAccounts = await ethereum.request({method:"eth_accounts"});
        // console.log(ETHAccounts.length)
        if(ETHAccounts.length ==0)
        {
        alert('No accounts is connected')
        }
    const provider = new ethers.providers.Web3Provider(ethereum);
    const signer = provider.getSigner();
    const contract = new ethers.Contract(greetingAddress,abi.abi,signer);
    const transaction = await contract.setGreeting(this.state.greeting);
    this.setState({ loading:'We are fetching your wish message, please wait....'})
    await transaction.wait();
    this.fetchGreeting();
    }
 handleChange(event) {
    this.setState({greeting: event.target.value});
    }
    render() {
        return(
            <Fragment>
                <textarea 
                    className='form-control'
                    // onChange={e => setGreetingValue(e.target.value)}
                    onChange={this.handleChange}
                    value={this.state.value}
                    name="message"
                    placeholder='What are your wishes for me?'
                    name="value"
                    ></textarea>
                    <p>{this.state.loading}</p>
                    <button className="waveButton" onClick={this.setGreeting}>
                    Send your wishes
                    </button>

                    <button className="waveButton" onClick={this.fetchGreeting}>
                    See wishes
                    </button>
            </Fragment>
        )
    }
}

export default MainGreeting;