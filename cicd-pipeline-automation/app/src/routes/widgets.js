const { Router } = require('express');

const router = Router();

// In-memory store — this service exists to demonstrate the pipeline,
// not to be a real inventory system. A real deployment would back
// this with RDS/DynamoDB.
let widgets = [
  { id: 1, name: 'Widget A', quantity: 42 },
  { id: 2, name: 'Widget B', quantity: 7 },
];
let nextId = 3;

router.get('/', (req, res) => {
  res.json(widgets);
});

router.get('/:id', (req, res) => {
  const widget = widgets.find((w) => w.id === Number(req.params.id));
  if (!widget) return res.status(404).json({ error: 'widget not found' });
  return res.json(widget);
});

router.post('/', (req, res) => {
  const { name, quantity } = req.body;
  if (typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ error: 'name is required' });
  }
  if (!Number.isInteger(quantity) || quantity < 0) {
    return res.status(400).json({ error: 'quantity must be a non-negative integer' });
  }
  const widget = { id: nextId++, name, quantity };
  widgets.push(widget);
  return res.status(201).json(widget);
});

router.delete('/:id', (req, res) => {
  const before = widgets.length;
  widgets = widgets.filter((w) => w.id !== Number(req.params.id));
  if (widgets.length === before) return res.status(404).json({ error: 'widget not found' });
  return res.status(204).send();
});

module.exports = router;
