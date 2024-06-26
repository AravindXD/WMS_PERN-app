const Pool= require("pg").Pool;

const pool=new Pool({
    user:"postgres",
    password:"aravind123",
    host:"localhost",
    port:5432,
    database:"Warehouses"
});

module.exports=pool;
