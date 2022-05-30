import ws from 'k6/ws';
import { check } from 'k6';

export default (): void => {
  const socket_url = process.env.SOCKET_URL as string;
  const params = {
    headers: {'clientMessage': 'my-message'}
  };

  const res = ws.connect(socket_url, params, (socket) => {
    socket.on('open', () => console.log('connected'));
    socket.on('error', (e) => {
      if (e.error() != 'websocket: close sent') {
        console.log('An unexpected error occured: ', e.error());
      }
    });
    socket.on('message', (data) => console.log('Message received: ', data));
    socket.on('close', () => console.log('disconnected'));
  });

  check(res, { 'status is 101': (r) => r && r.status === 101 });
}
