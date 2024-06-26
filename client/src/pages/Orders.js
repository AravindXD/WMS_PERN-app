import React, { useState, useEffect } from "react";
import { useLocation } from "react-router-dom";

function Orders() {
  const { state } = useLocation();
  const [orders, setOrders] = useState([]);
  console.log(state);

  useEffect(() => {
    const fetchOrders = async () => {
      try {
        console.log(state.pass);
        const response = await fetch(`http://localhost:5001/orders/${state.pass}`);
        const data = await response.json();
        setOrders(data);
      } catch (error) {
        console.error('Error fetching orders:', error);
      }
    };

    fetchOrders();
  }, [state]);

  return (
    <div>
      <h1>Orders</h1>
      <ul>
        {orders.map(order => (
          <li key={order.order_id}>
            Order ID: {order.order_id}, Crate ID: {order.crate_id}, Price: {order.price}
          </li>
        ))}
      </ul>
    </div>
  );
}

export default Orders;
