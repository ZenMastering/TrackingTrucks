import "./Home.css";
import Navbar from "./components/NavBar";
import MapView from "./components/MapView";

function Home() {
  return (
    <div className="home">
      <Navbar />
      <MapView />
    </div>
  );
}

export default Home;