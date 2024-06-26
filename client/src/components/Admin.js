import React from "react";
import { useNavigate } from "react-router-dom";

function Admin() {
  const navigate = useNavigate();
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
      const response = await fetch('http://localhost:5001/admin/checkCredentials', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name, password })
      });

      if (!response.ok) {
        alert('Invalid credentials. Please try again.');
        return;
      }

      // Admin credentials are valid, navigate to admin dashboard or any other page
      navigate('/admin',{state}); // Replace '/admin-dashboard' with the actual admin dashboard route

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
    <div className="form-container sign-up-container">
      <form onSubmit={handleOnSubmit}>
        <h1>Administrator Login</h1>
        <input
          type="text"
          name="name"
          value={state.name}
          onChange={handleChange}
          placeholder="Name"
          required
        />

        <input
          type="password"
          name="password"
          value={state.password}
          onChange={handleChange}
          placeholder="Password"
          required
        />
        <button>Admin Login</button>
      </form>
    </div>
  );
}

export default Admin;
