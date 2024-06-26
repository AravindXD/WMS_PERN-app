import React, { useState, useEffect } from "react";

function AllCrates() {
  const [crates, setCrates] = useState([]);

  useEffect(() => {
    const fetchCrates = async () => {
      try {
        const response = await fetch('http://localhost:5001/admin');
        const data = await response.json();
        console.log(data);
        setCrates(data);
      } catch (error) {
        console.error('Error fetching crates:', error);
      }
    };

    fetchCrates();
  }, []);

  return (
    <div className="container">
      <h1 className="title">All Crates</h1>
      <div className="crate-container">
        {crates.map(crates => {
          return (
            <div key={crates.crate_id} className="crate-card">
              <h3>Item_Type:{crates.crate_type}</h3>
              <p>Crate_id: {crates.crate_id}</p>
              <p>Weight: {crates.weight}kg</p>
              <p>Length: {crates.length}m</p>
              <p>Breadth: {crates.breadth}m</p>
              <p>Height: {crates.height}m</p>
              <p>NFC_ID: {crates.nfc_id}</p>
              <p>Check_in: {crates.check_in_time}</p>
              <p>Expected Departure: {crates.expected_departure}</p>
            </div>
          );
        })}
      </div>
      <style jsx>{`
        .container {
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 20px;
          padding-top: 4100px;
        }

        .title {
          font-size: 24px;
        }

        .crate-container {
          display: flex;
          flex-wrap: wrap;
          justify-content: center;
          max-width: 800px;
          margin: 10px;
          padding: 10px;
          background-color: #ffffff;
        }

        .crate-card {
          flex: 1 0 300px;
          margin: 10px;
          padding: 20px;
          background-color: #ff416c; /* Card background color */
          color: #fff; /* Text color */
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
          width: 100%;
          max-width: 300px;
        }
      `}</style>
    </div>
  );
}

export default AllCrates;
