export default function IndexRoute() {
  return (
    <div className="page">
      <header className="header">
        <a className="brand" href="/" aria-label="TrackingTrucks home">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
            <path d="M3 6h11v11H3zM14 10h4l3 4v3h-7" />
            <circle cx="7" cy="18" r="2" fill="currentColor" stroke="none" />
            <circle cx="18" cy="18" r="2" fill="currentColor" stroke="none" />
          </svg>
          TrackingTrucks
        </a>
        <span className="badge">Coming soon</span>
      </header>
      <main className="home">
        <p className="eyebrow">KEEP MOVING FORWARD</p>
        <h1>Your fleet.<br /><span>In view.</span></h1>
        <p className="intro">A simpler way to keep track of your trucks. We're getting things ready.</p>
      </main>
      <footer className="footer">TrackingTrucks &middot; Built for the road ahead.</footer>
    </div>
  );
}
