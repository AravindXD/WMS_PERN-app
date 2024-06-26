import React, { useState } from "react";
import Customer from "../components/Customer";
import Admin from "../components/Admin";

export default function Home() {
    const [type, setType] = useState("signIn");
    const handleOnClick = text => {
        if (text !== type) {
            setType(text);
            return;
        }
    };

    const containerClass = "container " + (type === "signUp" ? "right-panel-active" : "");

    return (
        <div className="App">
            <div className="Heading">
                <h2>Warehouse Management</h2>
            </div>
            <div className={containerClass} id="container">

                <Admin />
                <Customer />
                <div className="overlay-container">
                    <div className="overlay">
                        <div className="overlay-panel overlay-left">
                            <h1>Are you a customer?</h1>
                            <p>
                                Click to go to the Customer Login
                            </p>
                            <button
                                className="ghost"
                                id="signIn"
                                onClick={() => handleOnClick("signIn")}
                            >
                                Go to Customer Login
                            </button>
                        </div>
                        <div className="overlay-panel overlay-right">
                            <h1>Are you an Admin?</h1>
                            <p>Admin access to CRUD in Warehouse</p>
                            <button
                                className="ghost "
                                id="signUp"
                                onClick={() => handleOnClick("signUp")}
                            >
                                Go to Admin Login
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}