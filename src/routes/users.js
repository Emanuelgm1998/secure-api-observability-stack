import { Router } from 'express';
import { body } from 'express-validator';
import validate from '../middlewares/validate.js';
const router = Router();
const users = [];
router.get('/', (_req, res) => {
  res.json({ users });
});
router.post(
  '/',
  body('email').isEmail(),
  body('name').isString().isLength({ min: 2 }),
  validate,
  (req, res) => {
    const user = { id: users.length + 1, ...req.body };
    users.push(user);
    res.status(201).json(user);
  }
);
export default router;
