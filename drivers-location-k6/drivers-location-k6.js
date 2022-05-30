import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter } from 'k6/metrics';
export const requests = new Counter('http_reqs');

export const options = {
  stages: [
    { target: 20, duration: '20s' },
    { target: 10, duration: '20s' },
    { target: 0, duration: '20s' },
  ]
};

export default function () {
  const payload = process.env.data
  const headers = {
    'Content-Type': 'application/json',
    'dataType': 'json'
  };
  const res = http.request('POST', process.env.endpoint,
  payload,
  {
    headers: headers,
  });
  sleep(0.1);

  const checkRes = check(res, {
    'status is 200': (r) => r.status === 200,
  });
}
