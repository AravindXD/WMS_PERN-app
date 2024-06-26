const express = require("express");
const app = express();
const cors = require("cors");
const pool = require("./db");

// middleware
app.use(cors());
app.use(express.json());

// routes
// CHECK CUSTOMER CREDS
app.post("/customer/checkCredentials", async (req, res) => {
  try {
    const { name, password } = req.body;
    const customer = await pool.query("SELECT * FROM customer WHERE customer_name = $1 AND customer_id = $2", [name, password]);

    if (customer.rows.length > 0) {
      // Credentials are valid, send a success response
      res.status(200).json({ message: "Credentials are valid" });
    } else {
      // Credentials are invalid, send a failure response
      res.status(401).json({ message: "Invalid credentials" });
    }
  } catch (err) {
    console.error(err.message);
    res.status(500).send("Server Error");
  }
});


//GET ALL ORDERS FOR CUSTOMER_ID
app.get("/orders/:cust_id", async (req, res) => {
  try {
    const { cust_id } = req.params;
    const allOrders = await pool.query("SELECT * FROM orders WHERE customer_id = $1", [cust_id]);
    res.json(allOrders.rows);
  } catch (err) {
    console.error(err.message);
    res.status(500).send("Server Error");
  }
});

//GET ALL details of a crate from every order
app.get("/orders/:cust_id/:ordid", async (req, res) => {
    try {
      const { cust_id, ordid } = req.params; 
      const cratedet = await pool.query("SELECT * FROM customer WHERE customer_id = (SELECT customer_id FROM orders WHERE order_id = $1)", [ordid]);
      const tileid = await pool.query("SELECT tile_id FROM placedin WHERE crate_id = (SELECT crate_id FROM orders WHERE order_id = $1)", [ordid]);
      const tileloc = await pool.query("SELECT * FROM tile WHERE tile_id = $1", [tileid.rows[0].tile_id]);
      
      if (cust_id == cratedet.rows[0].customer_id) {
        res.json({ crate_details: cratedet.rows[0], tile_location: tileloc.rows[0] });
      } else {
        res.status(400).json({ error: "Bad request" });
      } 
    } catch (err) {
      console.error(err.message);
      res.status(500).json({ error: "Server Error" });
    }
  });

//UPDATE USER_NAME
app.put("/usnchg/:cus",async(req,res)=>{
    try{
        const {cus}=req.params;
        const {cus_name}= req.body;
        const updateName= await pool.query("UPDATE customer SET customer_name=$1 where customer_id=$2",[cus_name,cus]);
    
        res.json(`The customer_id ${cus}'s name was changed to ${cus_name}`);
    }

    catch(err){
        console.error(err.message);
    }
})

//CHECK ADMIN CREDS
app.post("/admin/checkCredentials", async (req, res) => {
  try {
    const { name, password } = req.body;
    const admin = await pool.query("SELECT * FROM admin WHERE admin_name = $1 AND admin_id = $2", [name, password]);

    if (admin.rows.length === 0) {
      // Admin credentials are invalid
      res.status(401).json({ message: "Invalid credentials" });
    } else {
      // Admin credentials are valid
      res.status(200).json({ message: "Credentials are valid" });
    }
  } catch (err) {
    console.error(err.message);
    res.status(500).send("Server Error");
  }
});

//ADMIN GET ALL CRATES
app.get("/admin", async (req, res) => {
  try {
    const allCrates = await pool.query("SELECT * FROM crate");
    res.json(allCrates.rows);
  } catch (err) {
    console.error(err.message);
    res.status(500).send("Server Error");
  }
});

//DELETE AN ORDER
app.delete("/orders/:id", async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query("DELETE FROM orders WHERE order_id = $1", [id]);
        res.json({ message: `Order ${id} was deleted` });
    } catch (err) {
        console.log(err.message);
        res.status(500).json({ error: "Server Error" });
    }
});



app.listen(5001, () => {
  console.log("Server has started on port 5001");
});
