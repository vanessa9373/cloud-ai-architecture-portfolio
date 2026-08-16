const express = require('express');
const healthRouter = require('./routes/health');
const widgetsRouter = require('./routes/widgets');

function createApp() {
  const app = express();
  app.use(express.json());

  app.use('/health', healthRouter);
  app.use('/widgets', widgetsRouter);

  app.use((req, res) => {
    res.status(404).json({ error: 'not found' });
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    res.status(500).json({ error: 'internal server error' });
  });

  return app;
}

module.exports = createApp;
