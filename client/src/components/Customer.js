import React from "react";
import { useNavigate } from "react-router-dom";
// https://media.istockphoto.com/id/1365436662/photo/successful-partnership.jpg?s=612x612&w=0&k=20&c=B1xspe9Q5WMsLc7Hc9clR8MWUL4bsK1MfUdDNVNR2Xg=
function Customer() {
  const navigate= useNavigate();
  const [state, setState] = React.useState({
    name: "",
    password: ""
  });
  const handleChange = evt => {
    const value = evt.target.value;
    setState({
      ...state,
      [evt.target.name]: value
    });
  };

  const handleOnSubmit = async evt => {
    evt.preventDefault();
  
    const { name, password } = state;
  
    try {
      const response = await fetch('http://localhost:5001/customer/checkCredentials', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name, password })
      });
  
  
      if (response.ok) {
        console.log(state); // Check if customer_id is present

        console.log(state);
        navigate('/orders', { state: {pass:password} });




      } else {
        // Credentials are invalid, show an alert
        alert('Invalid credentials. Please try again.');
      }
    } catch (error) {
      console.error('Error checking credentials:', error);
      alert('An error occurred while checking credentials. Please try again.');
    }
  
    // Clear the form fields
    setState({
      name: "",
      password: ""
    });
  };
  
  

  return (
    <div className="form-container sign-in-container">
      <form onSubmit={handleOnSubmit}>
        <h1>Customer</h1>

        <input
          type="name"
          placeholder="Name"
          name="name"
          value={state.name}
          onChange={handleChange}
          required
        />
        <input
          type="password"
          name="password"
          placeholder="your_id"
          value={state.password}
          onChange={handleChange}
          required
        />
        <button >Customer Login</button>
      </form>
    </div>
  );
}

export default Customer;