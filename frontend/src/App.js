import React, { useEffect, useState } from 'react';
import './App.css';

function App() {
  const [topics, setTopics] = useState([]);

  useEffect(() => {
    fetch('/api/topics')
      .then(res => res.json())
      .then(data => setTopics(data));
  }, []);

  return (
    <div>
      <h1>DevOps Quiz</h1>
      <ul>
        {topics.map(topic => (
          <li key={topic.id}>{topic.name}</li>
        ))}
      </ul>
    </div>
  );
}

export default App;
