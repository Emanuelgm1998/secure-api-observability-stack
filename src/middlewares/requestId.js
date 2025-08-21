import { v4 as uuid } from 'uuid';
export default function requestId(req, _res, next) {
  req.id = req.headers['x-request-id'] || uuid();
  next();
}
