const { Router } = require('express');

const router = Router();

// Polled by the ALB target group health check and by the deploy
// pipeline's smoke test after every rollout.
router.get('/', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    env: process.env.APP_ENV || 'development',
    uptimeSeconds: Math.round(process.uptime()),
  });
});

module.exports = router;
