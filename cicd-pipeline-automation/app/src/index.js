const createApp = require('./app');

const PORT = process.env.PORT || 3000;
const app = createApp();

app.listen(PORT, () => {
  console.log(`widget-inventory-api listening on port ${PORT} [env=${process.env.APP_ENV || 'development'}]`);
});
