import "./components/styles.css";
import { Routes, Route } from "react-router-dom";
import Home from "./pages/Home";
import Orders from "./pages/Orders";
import AllCrates from "./pages/AllCrates";

export default function App() {

  return (
    <Routes>
      <Route path="/" element={<Home></Home>}></Route>
      <Route path="/orders/" element={<Orders></Orders>}></Route>
      <Route path="/admin" element={<AllCrates/>}></Route>
    </Routes>
    
  );
}