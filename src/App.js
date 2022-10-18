import React, { useEffect, useState } from 'react';
import Button from './components/Buttons';
import MainGreeting from './components/MainGreeting';
import './App.css';

function App() {
  const [message, setMessage] = useState('');
  const [notification, setNotification] = useState('');
  const [notificationButton, setNotificationButton] = useState('');
  const [currentAccount, setCurrentAccount] = useState('');
  const [notificationBgClass, setNotificationBgClass] = useState('bgWarning');
  const [notificationCode, setNotificationCode] = useState(''); ///200 => success, 400 => error, 404 =>No metamask found
  const { ethereum } = window;

  const getHour = () => {
    const date = new Date();
    const hour = date.getHours();
    const splitAfternoon = 12; // 24hr time to split the afternoon
    const splitEvening = 17; // 24hr time to split the evening
    let message = "Good Morning";   // Between dawn and noon
    if (hour >= splitAfternoon && hour <= splitEvening) {
      // Between 12 PM and 5PM
      message = "Good Afternoon";
    } else if (hour >= splitEvening) {
      // Between 5PM and Midnight
      message = "Good Evening";
    }
  }

    const downloadMetamask = () => {
      window.open("https://metamask.io/download/");
    };

    //// checkIfWalletisConnected() function checks if metamask is injected in the web browser
    const checkIfWalletisConnected = async () => {
      try {
        if (!ethereum) {
          setNotification('You do not have Metamask app or web browser extension installed. Please click the button below to download and install one');
          setNotificationButton('Download Metamask!')
          setNotificationCode('404'); /// No metamask found
          setNotificationBgClass('bgDanger');
        }
        else {
          ////Checking of an ETH account exists
          checkForAuthAccount();
        }

      }
      catch (error) {
        console.log(error);
      }
    }

    const checkForAuthAccount = async () => {
      ///Checking if an account is connected
      const ETHAccounts = await ethereum.request({ method: "eth_accounts" });
      // console.log(ETHAccounts.length)
      if (ETHAccounts.length !== 0) {
        const AuthAccount = ETHAccounts[0];
        setNotification("You are connected with : " + AuthAccount, "<b/>");
        setNotificationCode('success');
        setNotificationCode('200'); /// Successfully connected
        setNotificationBgClass('bgInfo');
      }
      else {
        setNotification('You need to connect your account to continue!');
        setNotificationCode('error');
        setNotificationButton('Connect with your wallet!')
        setNotificationCode('405'); /// No metamask found
        setNotificationBgClass('bgWarning');
      }
    }
    async function connectWallet() {
      try {
        if (!ethereum) {
          alert("You must install Metamask first");
          return;
        }
        const ETHAccounts = await ethereum.request({ method: "eth_requestAccounts" });
        setCurrentAccount(ETHAccounts[0]);
        // alert("Accounted connected sucessfully at: "+ ETHAccounts[0]);
        setNotification("You are connected with :", currentAccount, "<b/>");
        setNotificationBgClass('bgInfo');
      }
      catch (error) {
        console.log(error);
      }
    }

    useEffect(() => {
      getHour();
      checkIfWalletisConnected();
    }, [])
    return (
      <div className="mainContainer">

        <div className="dataContainer">
          <div className="header">
            👋 Hey, {message} <br /> I am Agbo Boniface
          </div>

          <div className="bio">
            <p>I will love to know what you wish me in <b>2022</b>.</p>
          </div>
          {notification && (
            <div className={notificationBgClass}>
              <p>{notification}</p>
            </div>
          )
          }
          {notificationCode == 404 && (
            <Button
              notificationButton={notificationButton}
              clickFunc={downloadMetamask}
              classToAdd='btnWarning'
            />
          )
          }
          {notificationCode == 405 && (
            <Button
              notificationButton={notificationButton}
              clickFunc={connectWallet}
              classToAdd='btnInfo'
            />
          )
          }
          {
            notificationCode == 200 && (
              <MainGreeting />
            )
          }
        </div>
      </div>
    );
  }

  export default App;
