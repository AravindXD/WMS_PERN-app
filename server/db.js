const Pool= require("pg").Pool;

const pool=new Pool({
    user:"postgres",
    password:"aravind123", //YOUR PASSWORD
    host:"localhost",
    port:5432,
    database:"Warehouses"
});

module.exports=pool;
